// Source: https://github.com/tlvince/nixos-config/blob/master/.github/scripts/compare.js
const generateCompareLinks = (flakeUpdateOutput) => {
    // Updated regex to handle modern Nix flake update format with narHash parameters
    const regex =
        /'github:(?<repo>[^/]+\/[^/]+)\/(?<oldCommit>[0-9a-f]+)(?:\?[^']*)?'\s*\([^)]+\)\s*→\s*'github:\1\/(?<newCommit>[0-9a-f]+)(?:\?[^']*)?'/g;

    let match;
    const links = [];

    while ((match = regex.exec(flakeUpdateOutput)) !== null) {
        const { repo, oldCommit, newCommit } = match.groups;
        // Only create compare URL if commits are different
        if (oldCommit !== newCommit) {
            const compareUrl = `https://github.com/${repo}/compare/${oldCommit}...${newCommit}`;
            links.push(`[${repo}](${compareUrl})`);
        }
    }

    return links;
};

module.exports = async ({ core }) => {
    const { GIT_COMMIT_MESSAGE } = process.env;
    if (!GIT_COMMIT_MESSAGE) {
        core.warning("unable to determine latest commit message");

        // Try fallback method using git diff
        try {
            const { generateCompareLinksFromDiff } = require('./compare-fallback.js');
            const fallbackLinks = generateCompareLinksFromDiff();
            if (fallbackLinks.length > 0) {
                core.info(`Found ${fallbackLinks.length} compare link(s) using fallback method`);
                return fallbackLinks;
            }
        } catch (error) {
            core.warning(`Fallback method also failed: ${error.message}`);
        }

        return [];
    }

    core.info(`Processing commit message: ${GIT_COMMIT_MESSAGE.substring(0, 200)}...`);

    const compareLinks = generateCompareLinks(GIT_COMMIT_MESSAGE);
    if (!compareLinks.length) {
        core.warning("no compare links found in commit message");

        // Try fallback method if primary method fails
        try {
            const { generateCompareLinksFromDiff } = require('./compare-fallback.js');
            const fallbackLinks = generateCompareLinksFromDiff();
            if (fallbackLinks.length > 0) {
                core.info(`Found ${fallbackLinks.length} compare link(s) using fallback method`);
                return fallbackLinks;
            }
        } catch (error) {
            core.warning(`Fallback method also failed: ${error.message}`);
        }

        return [];
    }

    core.info(`Found ${compareLinks.length} compare link(s)`);
    return compareLinks;
};