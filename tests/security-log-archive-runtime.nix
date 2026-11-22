{ pkgs }:
let
  package = pkgs.callPackage ../packages/security-log-archive { };
in
pkgs.testers.runNixOSTest {
  name = "security-log-archive-runtime";
  nodes = {
    receiver = {
      environment.systemPackages = [
        pkgs.restic
        pkgs.rclone
        pkgs.python3
        pkgs.openssh
      ];
      services.openssh.enable = true;
      users.users.archive = {
        isNormalUser = true;
        home = "/home/archive";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGoJQoGpAoRuSbAoQTdCbGRc3xJQ77aCpHwoXTjpSiHp fixture-placeholder"
        ];
      };
    };
    source = { config, lib, ... }: {
      imports = [ ../modules/services/security-log-archive.nix ];
      environment.systemPackages = [
        package
        pkgs.restic
        pkgs.python3
        pkgs.openssh
      ];
      sys.services.securityLogArchive = {
        enable = true;
        sourceHost = "source";
        sshTarget = "archive@receiver";
        repositoryId = lib.concatStrings (lib.replicate 64 "0");
        knownHostsFile = "/etc/archive-known-hosts";
        identityFile = "/var/lib/archive-test/upload-ssh";
        passwordFile = "/var/lib/archive-test/password";
        heartbeatUrlFile = "/var/lib/archive-test/heartbeat-url";
        bufferBytes = 256 * 1024 * 1024;
        minFreeBytes = 0;
      };
      # Only this disposable fixture replaces the public repository ID at
      # runtime; production pins it in the reviewed host configuration.
      systemd.services.security-log-archive-upload = {
        path = [
          pkgs.restic
          pkgs.openssh
          pkgs.systemd
        ];
        serviceConfig.ExecStart = lib.mkForce "${package}/bin/security-log-archive --config /etc/archive-runtime.json upload";
      };
      systemd.timers.security-log-archive-upload.wantedBy = lib.mkForce [ ];
      environment.etc."archive-template.json".source =
        config.sys.services.securityLogArchive.clientConfigFile;
    };
  };
  testScript = ''
    import json
    import shlex

    start_all()
    receiver.wait_for_unit("sshd.service")
    source.wait_for_unit("security-log-archive-collector.service")
    source.succeed("install -d -m 0700 /var/lib/archive-test")
    source.succeed("ssh-keygen -q -t ed25519 -N '${""}' -f /var/lib/archive-test/upload-ssh")
    receiver.succeed("ssh-keygen -q -t ed25519 -N '${""}' -f /tmp/admin-ssh")
    public_upload = source.succeed("cat /var/lib/archive-test/upload-ssh.pub").strip()
    public_admin = receiver.succeed("cat /tmp/admin-ssh.pub").strip()
    authorized = 'restrict,command="${pkgs.rclone}/bin/rclone serve restic --stdio --append-only /home/archive/blizzard-security-logs" ' + public_upload + '\n' + public_admin + '\n'
    receiver.succeed("rm /etc/ssh/authorized_keys.d/archive")
    receiver.succeed("printf %s " + shlex.quote(authorized) + " > /etc/ssh/authorized_keys.d/archive")
    receiver.succeed("printf fixture-password > /tmp/archive-password; chmod 0644 /tmp/archive-password")
    receiver.succeed("runuser -u archive -- restic --repo /home/archive/blizzard-security-logs --password-file /tmp/archive-password init")
    repo = json.loads(receiver.succeed("restic --repo /home/archive/blizzard-security-logs --password-file /tmp/archive-password cat config"))
    host_key = receiver.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub").strip()
    known_hosts = 'receiver ' + host_key + '\n'
    source.succeed("printf %s " + shlex.quote(known_hosts) + " > /etc/archive-known-hosts")
    source.succeed("printf fixture-password > /var/lib/archive-test/password")
    # Invalid test-only URL is rejected before any network request to a real
    # monitoring service. Pure tests cover accepted and failed heartbeat calls.
    source.succeed("printf no-external-monitor > /var/lib/archive-test/heartbeat-url")
    source.succeed("python3 -c " + shlex.quote("import json; p=json.load(open('/etc/archive-template.json')); p['repository_id']=" + repr(repo['id']) + "; json.dump(p,open('/etc/archive-runtime.json','w'))"))

    def emit(path):
        entry = json.dumps({'ClientHost':'198.51.100.42', 'RequestMethod':'GET', 'RequestPath':path + '?token=ARCHIVE_SECRET', 'DownstreamStatus':200, 'request_User-Agent':'archive-fixture', 'Authorization':'ARCHIVE_SECRET'})
        source.succeed("systemd-run --unit=traefik --wait --collect ${pkgs.coreutils}/bin/printf '%s\\n' " + shlex.quote(entry))
        try:
            source.wait_until_succeeds("grep -F " + shlex.quote(path) + " /var/lib/security-log-archive/ready/*.jsonl", timeout=60)
        finally:
            print(source.succeed("journalctl -u security-log-archive-collector.service --no-pager -n 30"))
            print(source.succeed("ls -la /var/lib/security-log-archive /var/lib/security-log-archive/ready"))

    # The generated transport consumes only its credential-directory key.
    source.succeed("install -d -m 0700 /var/lib/archive-test/credentials; cp /var/lib/archive-test/upload-ssh /var/lib/archive-test/credentials/upload-ssh")
    transport = json.loads(source.succeed("cat /etc/archive-runtime.json"))['upload_options']['rclone.program']
    # Restic must not change input flags on the test driver's serial terminal.
    restic = "CREDENTIALS_DIRECTORY=/var/lib/archive-test/credentials ${pkgs.restic}/bin/restic </dev/null --repo rclone:blizzard-security-logs --password-file /var/lib/archive-test/password -o " + shlex.quote('rclone.program=' + transport) + " -o 'rclone.args=serve restic --stdio --append-only' "
    source.succeed(restic + "cat config")

    emit('/archive-before-outage')
    source.succeed("systemctl start security-log-archive-upload.service")
    source.succeed("test -s /var/lib/prometheus-node-exporter/security-log-archive/archive.prom")
    source.succeed("grep -F 'security_log_archive_upload_timestamp_seconds' /var/lib/prometheus-node-exporter/security-log-archive/archive.prom")
    receiver.succeed("restic --repo /home/archive/blizzard-security-logs --password-file /tmp/archive-password check --read-data")

    # The upload identity cannot execute a shell or read another repository.
    ssh = "ssh -n -F /dev/null -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/etc/archive-known-hosts -i /var/lib/archive-test/upload-ssh archive@receiver "
    source.execute(ssh + shlex.quote('touch /tmp/UNRESTRICTED_ARCHIVE_SHELL'))
    receiver.fail("test -e /tmp/UNRESTRICTED_ARCHIVE_SHELL")

    before = receiver.succeed("find /home/archive/blizzard-security-logs/snapshots -type f | wc -l").strip()
    # Restic 0.18 can return zero even when individual removals failed.
    # The denial and unchanged receiver data establish the actual boundary.
    # Run the negative operation in a detached service, like production uploads.
    # Its terminal handling must not affect the VM driver's serial shell.
    source.execute("systemd-run --unit=archive-delete-fixture --wait --collect --property=RuntimeMaxSec=30s sh -c " + shlex.quote(restic + "forget --keep-last 0 --unsafe-allow-remove-all --tag security-log-archive-v1 >/tmp/archive-delete-result 2>&1"))
    deletion_output = source.succeed("cat /tmp/archive-delete-result")
    assert "403 Forbidden" in deletion_output, deletion_output
    assert receiver.succeed("find /home/archive/blizzard-security-logs/snapshots -type f | wc -l").strip() == before

    # A network outage leaves all unacknowledged evidence in the source spool.
    receiver.succeed("systemctl stop sshd.service")
    emit('/archive-during-outage')
    source.fail("systemctl start security-log-archive-upload.service")
    source.succeed("grep -F archive-during-outage /var/lib/security-log-archive/ready/*.jsonl")
    source.succeed("systemctl stop security-log-archive-collector.service")
    source.shutdown()
    source.start()
    source.wait_for_unit("security-log-archive-collector.service")
    source.succeed("grep -F archive-during-outage /var/lib/security-log-archive/ready/*.jsonl")
    receiver.succeed("systemctl start sshd.service")
    source.succeed("systemctl start security-log-archive-upload.service")
    source.wait_until_succeeds("test $(find /var/lib/security-log-archive/ready -name '*.jsonl' | wc -l) -le 1")

    # Verify old snapshots and all event hashes with the source offline.
    source.shutdown()
    snapshots = json.loads(receiver.succeed("restic --repo /home/archive/blizzard-security-logs --password-file /tmp/archive-password snapshots --json"))
    receiver.succeed("install -d -m 0700 /tmp/recovered")
    for index, snapshot in enumerate(snapshots):
        directory = '/tmp/recovered/' + str(index)
        receiver.succeed("restic --repo /home/archive/blizzard-security-logs --password-file /tmp/archive-password restore --verify " + snapshot['id'] + " --target " + directory)
    receiver.succeed("grep -R -F archive-before-outage /tmp/recovered")
    receiver.succeed("grep -R -F archive-during-outage /tmp/recovered")
    receiver.fail("grep -R -F ARCHIVE_SECRET /tmp/recovered")
    receiver.succeed("restic --repo /home/archive/blizzard-security-logs --password-file /tmp/archive-password check --read-data")
  '';
}
