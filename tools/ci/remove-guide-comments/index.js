const core = require('@actions/core');
const github = require('@actions/github');
const emoji_pattern = /([\uD800-\uDBFF][\uDC00-\uDFFF]|[\u2000-\u3300]|[\u00A9-\u00AE]|[\uFE0F])\s?/g;

async function doAsyncAction() {
  try {
    const token = core.getInput('repo-token', { required: true });
    const strip_title = core.getInput('title');
    const strip_body = core.getInput('body');

    if (!github.context.payload.pull_request) {
      core.setFailed('PR payload retrieval failed.'); // could just be a throw since in a try already *shrug
      return;
    }
    const pr_number = github.context.payload.pull_request.number;
    const octokit = github.getOctokit(token);

    let request_options = {
      owner: github.context.repo.owner,
      repo: github.context.repo.repo,
      pull_number: pr_number
    };

    const pull_octo_res = await octokit.rest.pulls.get(request_options);

    // with: title = true
    if (strip_title.toLowerCase() === 'true') {
      request_options['title'] = stripTitle(pull_octo_res.data.title);
    }
    // with: body = true
    if (strip_body.toLowerCase() === 'true' && pull_octo_res.data.body) {
      request_options['body'] = stripBody(pull_octo_res.data.body, core.getInput('body-after'), core.getInput('body-before'));
    }

    // only update if there is something to change
    if (request_options.title || request_options.body) {
      await octokit.rest.pulls.update(request_options);
    }
  } catch (error) {
    core.setFailed('Action failed. Error: ' + error.message);
  }
}

function stripTitle(pr_title) {
  const stripped_title = pr_title.replace(emoji_pattern, '');
  if (pr_title === stripped_title)
    return;

  return (stripped_title.trim() === '') ? 'A title without emoji' : stripped_title; // just in case some joker puts only emoji, PR titles can not blank
}

function stripBody(raw_body, body_after, body_before) {
  let stripped_body = raw_body, pre_text = '', post_text = '';

  if (body_after) {
    if (stripped_body.indexOf(body_after) === -1){
      core.info(`No match for body-after: "${body_after}"`);
      return;
    }
    pre_text = stripped_body.substring(0, stripped_body.indexOf(body_after) + body_after.length);
    stripped_body = stripped_body.substring(stripped_body.indexOf(body_after) + body_after.length);
  }
  if (body_before) {
    if (stripped_body.lastIndexOf(body_before) === -1){
      core.info(`No match for body-before: "${body_before}"`);
      return;
    }
    post_text = stripped_body.substring(stripped_body.lastIndexOf(body_before));
    stripped_body = stripped_body.substring(0, stripped_body.lastIndexOf(body_before));
  }

  stripped_body = pre_text + stripped_body.replace(emoji_pattern, '') + post_text;

  if (raw_body === stripped_body)
    // no emoji where it shouldn't be :)
    return;

  return stripped_body;
}

doAsyncAction();
