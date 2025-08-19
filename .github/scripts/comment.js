// Source: https://github.com/tlvince/nixos-config/blob/master/.github/scripts/comment.js
module.exports = async ({ github, context, header, body, issueNumber }) => {
    const issue_number = issueNumber || context.issue.number;

    try {
        const { data: comments } = await github.rest.issues.listComments({
            owner: context.repo.owner,
            repo: context.repo.repo,
            issue_number,
        });

        const botComment = comments.find(
            (comment) =>
                // github-actions bot user
                comment.user.id === 41898282 && comment.body.startsWith(header),
        );

        const comment = [header, body].join("\n\n");
        const commentFn = botComment ? "updateComment" : "createComment";

        await github.rest.issues[commentFn]({
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: comment,
            ...(botComment ? { comment_id: botComment.id } : { issue_number }),
        });

        console.log(`${botComment ? 'Updated' : 'Created'} comment on PR #${issue_number}`);
    } catch (error) {
        console.error('Error managing comment:', error);
        throw error;
    }
};