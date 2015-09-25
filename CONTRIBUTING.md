<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [Roles](#roles)
- [Terms](#terms)
- [Contributing to this repository](#contributing-to-this-repository)
- [Must-reads](#must-reads)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->


This repo adheres to the SaasBase development guideline:
**[SaasBase Contribution Guide](http://saasbase.corp.adobe.com/guides/saasbase_contributors.html)**

We are using the **[fork-pullrequest-merge](https://help.github.com/articles/using-pull-requests)** model to integrate new fixes/improvements in our mainline repository:
`git@git.corp.adobe.com:adobe-apis/api-gateway-request-tracking.git`

###Roles

* **Contributors**: Any active Api-Gateway developer or other Adobe contributor
* **Maintainer**  : One of the Api-Gateway developers doing pro-bono repository maintanance

###Terms

* **Main repository**: `master` branch in `git@git.corp.adobe.com:adobe-apis/api-gateway-request-tracking.git` repository governed by strict integration policy (i.e: master branch is always stable, ready for release)
* **Contributors workspace** :
  * Contributors fork the the main repository and [do all the development work in this repo](https://git.corp.adobe.com/adobe-apis/api-gateway-request-tracking).
  * (OR) Work on individual feature branches in `adobe-apis/api-gateway-request-tracking` repository


###Contributing to this repository


1. A Contributor SHALL [**file a JIRA issue**](https://it.jira.corp.adobe.com/secure/CreateIssueDetails!init.jspa?pid=13502&issuetype=4&components=Gateway), assuming one does not already exist, clearly describing the issue including steps to reproduce when it is a bug.

1. To work on an issue, a Contributor SHALL **create a new feature branch** within `adobe-apis/api-gateway-request-tracking` repo:

        git checkout -b WS-999 origin/master

1. During the development process, a Contributor SHALL ensure the following requirements are met:
    * Code-style is followed:
        * 4 space indentation, no tabs for puppet and scripts
        * Google Code Style for Java
    * Documentation is added/updated (internal/external)
    * Nginx specific integration tests all pass
    * Update Release Notes file and fill in the comments section of CHANGES.txt file external customer configuration instructions

1. To submit a patch, a Contributor SHALL ensure that **commit message is properly formatted**:
    * The commit title should contain the Jira ID and description
        * e.g. `[WS-999] - Jira description`
        * The following lines could have a detailed description if needed.
        * When the commit is (exceptionally) appending to a previous commit use the following template:
            *  `[JIRA-ID] Jira Issue Title ADDENDUM`
    * There a couple of exceptions to the rule above when a JIRA issue is not required.  
    However a review is still encouraged mostly because it keeps changes clean and the team informed.
        * `[DOC] - Description of the documentation change`
        * `[COSMETIC] - Description of cosmetic change`
        * `[RELEASE] - Commit to crease a release artefact`

1. To submit a patch, a Contributor SHALL [create a pull request](http://saasbase.corp.adobe.com/guides/pull_request_workflow.html) on git.corp.adobe.com back on `adobe-apis/api-gateway-request-tracking` project.  
The team will be notified via email about the new PR

        git push -u origin WS-999:WS-999

1. Repo Maintainers and other Contributors are [reviewing the pull-request](http://saasbase.corp.adobe.com/guides/code_review.html) on git.corp.adobe.com giving feedback and proposing changes if necessary.  
A reviewer agrees on the final version of the patch by posting a **+1** message on pull-request discussion thread.

1. Once the patch is reviewed and accepted by **at least two maintainers** and has **no vetoes**, the patch is accepted and ready to be **pushed** into the main repository.

1. Contributors SHALL [**squash**](http://gitready.com/advanced/2009/02/10/squashing-commits-with-rebase.html) individual commits in the pull-request.

1. Contributor SHALL [**rebase**](http://gitready.com/intermediate/2009/01/31/intro-to-rebase.html) the feature branch on top of latest chages in origin/master and SHALL *push* a single commit into the main repository

        git fetch origin
        git rebase -p origin/master
        git push origin WS-999:master

1. Contributor marks the JIRA issue as **Resolved** and updates the **Fix Version** field accordingly

###Must-reads

* [Open Development Principles at Adobe](https://wiki.corp.adobe.com/display/~bdelacre/Open+Development+Principles)
* [http://help.github.com/fork-a-repo/](http://help.github.com/fork-a-repo/)
* [http://unprotocols.org/blog:23](http://unprotocols.org/blog:23)
* [http://pcottle.github.io/learnGitBranching/](http://pcottle.github.io/learnGitBranching/)
