
const { execSync } = require('child_process');
const fs = require('fs');

const generateCompareLinksFromDiff = () => {
    try {
        const prBranch = process.env.PR_BRANCH || 'update_flake_lock_action';
        let flakeDiff;

        // Try different methods to get the diff
        try {
            // Method 1: Compare current branch with PR branch
            flakeDiff = execSync(`git diff HEAD..${prBranch} -- flake.lock 2>/dev/null || git diff origin/main..origin/${prBranch} -- flake.lock`, { encoding: 'utf8' });
        } catch {
            try {
                // Method 2: Get the diff from the last 2 commits on flake.lock
                const commits = execSync('git log -2 --pretty=format:"%H" -- flake.lock', { encoding: 'utf8' }).trim().split('\n');
                if (commits.length >= 2) {
                    const [newCommit, oldCommit] = commits;
                    flakeDiff = execSync(`git diff ${oldCommit} ${newCommit} -- flake.lock`, { encoding: 'utf8' });
                }
            } catch {
                // Method 3: Try to read current flake.lock and compare with staged/modified version
                flakeDiff = execSync('git diff HEAD -- flake.lock', { encoding: 'utf8' });
            }
        }

        if (!flakeDiff || !flakeDiff.trim()) {
            console.log('No flake.lock diff found');
            return [];
        }

        const links = [];
        const repos = new Map();

        // Parse the diff to find old and new revisions
        // Match lines like: -      "rev": "abc123..."
        // and:              +      "rev": "def456..."
        const lines = flakeDiff.split('\n');
        let currentRepo = null;

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];

            // Track which input we're in (look for "owner" and "repo" keys)
            const ownerMatch = line.match(/"owner":\s*"([^"]+)"/);
            const repoMatch = line.match(/"repo":\s*"([^"]+)"/);

            if (ownerMatch) {
                // Look ahead for repo
                for (let j = i; j < Math.min(i + 10, lines.length); j++) {
                    const repoLine = lines[j].match(/"repo":\s*"([^"]+)"/);
                    if (repoLine) {
                        currentRepo = `${ownerMatch[1]}/${repoLine[1]}`;
                        break;
                    }
                }
            }

            // Match removed revision (old)
            const oldRevMatch = line.match(/^-\s*"rev":\s*"([a-f0-9]+)"/);
            if (oldRevMatch && currentRepo) {
                if (!repos.has(currentRepo)) {
                    repos.set(currentRepo, {});
                }
                repos.get(currentRepo).old = oldRevMatch[1];
            }

            // Match added revision (new)
            const newRevMatch = line.match(/^\+\s*"rev":\s*"([a-f0-9]+)"/);
            if (newRevMatch && currentRepo) {
                if (!repos.has(currentRepo)) {
                    repos.set(currentRepo, {});
                }
                repos.get(currentRepo).new = newRevMatch[1];
            }
        }

        // Generate compare URLs for repos with both old and new revisions
        for (const [repo, revs] of repos) {
            if (revs.old && revs.new && revs.old !== revs.new) {
                const compareUrl = `https://github.com/${repo}/compare/${revs.old.substring(0, 12)}...${revs.new.substring(0, 12)}`;
                links.push(`[${repo}](${compareUrl})`);
            }
        }

        return links;
    } catch (error) {
        console.error('Error generating compare links from diff:', error.message);
        return [];
    }
};

module.exports = { generateCompareLinksFromDiff };
