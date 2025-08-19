
const { execSync } = require('child_process');
const fs = require('fs');

const generateCompareLinksFromDiff = () => {
    try {
        // Get the diff of flake.lock from the last 2 commits
        const diff = execSync('git log -2 --pretty=format:"%H" -- flake.lock', { encoding: 'utf8' }).trim().split('\n');

        if (diff.length < 2) {
            console.log('Not enough commits to compare');
            return [];
        }

        const [newCommit, oldCommit] = diff;
        const flakeDiff = execSync(`git diff ${oldCommit} ${newCommit} -- flake.lock`, { encoding: 'utf8' });

        const links = [];
        const repoRegex = /"owner":\s*"([^"]+)"[^}]*"repo":\s*"([^"]+)"[^}]*"rev":\s*"([^"]+)"/g;
        const oldRepoRegex = /-\s*"owner":\s*"([^"]+)"[^}]*"repo":\s*"([^"]+)"[^}]*"rev":\s*"([^"]+)"/g;

        let match;
        const repos = new Map();

        // Find old revisions (removed lines)
        while ((match = oldRepoRegex.exec(flakeDiff)) !== null) {
            const [, owner, repo, rev] = match;
            repos.set(`${owner}/${repo}`, { old: rev });
        }

        // Find new revisions (added lines) and create compare URLs
        while ((match = repoRegex.exec(flakeDiff)) !== null) {
            const [, owner, repo, rev] = match;
            const repoKey = `${owner}/${repo}`;
            if (repos.has(repoKey)) {
                const oldRev = repos.get(repoKey).old;
                if (oldRev !== rev) {
                    const compareUrl = `https://github.com/${repoKey}/compare/${oldRev}...${rev}`;
                    links.push(`[${repoKey}](${compareUrl})`);
                }
            }
        }

        return links;
    } catch (error) {
        console.error('Error generating compare links from diff:', error.message);
        return [];
    }
};

module.exports = { generateCompareLinksFromDiff };
