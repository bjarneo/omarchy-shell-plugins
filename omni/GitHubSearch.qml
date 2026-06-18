import QtQuick
import Quickshell.Io
import "Data.js" as Data

// GitHub CLI-backed search drill. Two surfaces:
//
//   query empty -> your PRs (authored, review-requested, mentioned,
//                  assigned), fetched on mode entry, deduped by URL.
//   query set   -> repo search (scoped: you + your orgs first,
//                  broad: the world after), debounced.
//
// Identity (login + orgs) is probed once at startup so both surfaces
// know who you are. Failures leave the owner filter empty and the
// search falls back to broad-only.
Item {
    id: githubSearch

    required property string query
    required property bool active
    required property var selectedItem

    property bool ready: false
    property string previewTitle: ""
    property string previewUrl: ""
    property string previewText: ""
    readonly property bool running: ownedRepositorySearchProc.running
                                    || globalRepositorySearchProc.running
                                    || authoredPullRequestsProc.running
                                    || reviewRequestedPullRequestsProc.running
                                    || mentionedPullRequestsProc.running
                                    || assignedPullRequestsProc.running

    // Identity, learned once at startup.
    property string userLogin: ""
    property var userOrgs: []
    readonly property string ownerFilter: githubSearch.userLogin
        ? [githubSearch.userLogin].concat(githubSearch.userOrgs).join(",")
        : ""

    // Raw arrays per upstream. items is derived from these.
    property var ownedRepositoryResults: []
    property var globalRepositoryResults: []
    property var authoredPullRequestResults: []
    property var reviewRequestedPullRequestResults: []
    property var mentionedPullRequestResults: []
    property var assignedPullRequestResults: []

    // Empty query -> PRs; non-empty -> repos. The four PR arrays are
    // merged in priority order (author > review-requested > mentions >
    // assignee) and deduped by URL. Repos merge your own first, then
    // your orgs', then the broad results.
    readonly property var items: {
        if (!githubSearch.active) return [];
        if (githubSearch.query.trim().length === 0) return githubSearch.pullRequestItems;
        return githubSearch.repositoryItems;
    }

    readonly property var pullRequestItems: {
        const seen = {};
        const out = [];
        const sources = [
            githubSearch.authoredPullRequestResults,
            githubSearch.reviewRequestedPullRequestResults,
            githubSearch.mentionedPullRequestResults,
            githubSearch.assignedPullRequestResults
        ];
        for (let s = 0; s < sources.length; s++) {
            const list = sources[s];
            for (let i = 0; i < list.length; i++) {
                const pullRequest = list[i];
                if (!seen[pullRequest.url]) {
                    seen[pullRequest.url] = true;
                    out.push(githubSearch.toPullRequestItem(pullRequest, s));
                }
            }
        }
        return out;
    }

    readonly property var repositoryItems: {
        const seen = {};
        const out = [];
        const userPrefix = githubSearch.userLogin ? githubSearch.userLogin + "/" : "";
        for (let i = 0; i < githubSearch.ownedRepositoryResults.length; i++) {
            const repository = githubSearch.ownedRepositoryResults[i];
            if (userPrefix && repository.fullName.indexOf(userPrefix) === 0) {
                seen[repository.url] = true;
                out.push(githubSearch.toRepositoryItem(repository));
            }
        }
        for (let i = 0; i < githubSearch.ownedRepositoryResults.length; i++) {
            const repository = githubSearch.ownedRepositoryResults[i];
            if (!seen[repository.url]) {
                seen[repository.url] = true;
                out.push(githubSearch.toRepositoryItem(repository));
            }
        }
        for (let i = 0; i < githubSearch.globalRepositoryResults.length; i++) {
            const repository = githubSearch.globalRepositoryResults[i];
            if (!seen[repository.url]) {
                seen[repository.url] = true;
                out.push(githubSearch.toRepositoryItem(repository));
            }
        }
        return out;
    }

    function clear() {
        githubSearch.ownedRepositoryResults = [];
        githubSearch.globalRepositoryResults = [];
        githubSearch.previewTitle = "";
        githubSearch.previewUrl = "";
        githubSearch.previewText = "";
        repositorySearchDebounce.stop();
    }

    function toRepositoryItem(repository) {
        const lang = repository.language ? "  ·  " + repository.language : "";
        return {
            title: repository.fullName,
            comment: repository.description || "",
            keywords: "",
            category: "★ " + Data.formatStars(repository.stargazersCount || 0) + lang,
            icon: "󰊤",
            path: repository.url,
            exec: Data.openUrl(repository.url),
            rawCategory: true
        };
    }

    // sourceIdx 0=author, 1=review-requested, 2=mentions, 3=assignee.
    // The tag shows up in the right column so you can tell at a glance
    // why a PR is in your list.
    readonly property var pullRequestTags: ["YOURS", "REVIEW", "MENTIONED", "ASSIGNED"]
    function toPullRequestItem(pullRequest, sourceIdx) {
        const repository = pullRequest.repository ? pullRequest.repository.nameWithOwner : "";
        return {
            title: pullRequest.title,
            comment: repository + "#" + pullRequest.number,
            keywords: "",
            category: repository + "#" + pullRequest.number + "  ·  " + githubSearch.pullRequestTags[sourceIdx],
            icon: "󰓂",
            path: pullRequest.url,
            exec: Data.openUrl(pullRequest.url),
            rawCategory: true,
            isPullRequest: true,
            pullRequestRepository: repository,
            pullRequestNumber: pullRequest.number,
            pullRequestBody: pullRequest.body || "",
            pullRequestAuthor: pullRequest.author && pullRequest.author.login ? pullRequest.author.login : "",
            pullRequestUpdatedAt: pullRequest.updatedAt || ""
        };
    }

    function pullRequestPreviewText(item) {
        const lines = [];
        const repositoryLine = (item.pullRequestRepository || "") + (item.pullRequestNumber ? "#" + item.pullRequestNumber : "");
        if (repositoryLine !== "") lines.push(repositoryLine);
        if (item.pullRequestAuthor) lines.push("author: " + item.pullRequestAuthor);
        if (item.pullRequestUpdatedAt) lines.push("updated: " + item.pullRequestUpdatedAt);
        if (item.path) lines.push(item.path);
        lines.push("");
        lines.push("TITLE");
        lines.push(item.title || "Untitled PR");
        lines.push("");
        lines.push("DESCRIPTION");
        lines.push((item.pullRequestBody || "").trim() || "No description provided.");
        return lines.join("\n");
    }

    function updatePreview() {
        if (!githubSearch.active) return;
        const item = githubSearch.selectedItem;
        const url = (item && item.path) || "";
        if (url === githubSearch.previewUrl) return;
        githubSearch.previewUrl = url;
        githubSearch.previewTitle = (item && item.title) || "";
        githubSearch.previewText = "";
        if (!url || !item.title) return;
        if (item.isPullRequest) {
            githubSearch.previewText = githubSearch.pullRequestPreviewText(item);
            return;
        }
        githubSearch.previewText = "Loading…";
        // gh api prints its 404 error body to stdout, so a naive pipe
        // would leak `{"message":"Not Found"...}` into the preview.
        // Capture first, only emit on exit success. Works for both repo
        // README endpoints and PR HEAD references.
        repositoryReadmeProc.command = ["sh", "-c",
            "out=$(gh api repos/\"$1\"/readme -H 'Accept: application/vnd.github.raw' 2>/dev/null) && printf '%s' \"$out\" | head -c 8192 || true",
            "sh", item.title.indexOf("#") >= 0 ? item.title.split("#")[0] : item.title];
        repositoryReadmeProc.running = false;
        repositoryReadmeProc.running = true;
    }

    function fetchPullRequests() {
        if (!githubSearch.ready) return;
        const fields = "title,url,number,repository,body,author,updatedAt";
        authoredPullRequestsProc.command = ["gh", "search", "prs", "--author=@me", "--state=open", "--json", fields, "--limit", "25"];
        reviewRequestedPullRequestsProc.command = ["gh", "search", "prs", "--review-requested=@me", "--state=open", "--json", fields, "--limit", "15"];
        mentionedPullRequestsProc.command = ["gh", "search", "prs", "--mentions=@me", "--state=open", "--json", fields, "--limit", "15"];
        assignedPullRequestsProc.command = ["gh", "search", "prs", "--assignee=@me", "--state=open", "--json", fields, "--limit", "15"];
        authoredPullRequestsProc.running = false; authoredPullRequestsProc.running = true;
        reviewRequestedPullRequestsProc.running = false; reviewRequestedPullRequestsProc.running = true;
        mentionedPullRequestsProc.running = false; mentionedPullRequestsProc.running = true;
        assignedPullRequestsProc.running = false; assignedPullRequestsProc.running = true;
    }

    onQueryChanged: { if (githubSearch.active) repositorySearchDebounce.restart(); }
    onSelectedItemChanged: { if (githubSearch.active) githubSearch.updatePreview(); }
    onItemsChanged: { if (githubSearch.active) githubSearch.updatePreview(); }
    onActiveChanged: { if (githubSearch.active && githubSearch.ready) githubSearch.fetchPullRequests(); }
    onReadyChanged: { if (githubSearch.active && githubSearch.ready) githubSearch.fetchPullRequests(); }

    Component.onCompleted: githubAuthProc.running = true

    Process {
        id: githubAuthProc
        running: false
        command: ["sh", "-c", "command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && echo ok || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                githubSearch.ready = this.text.indexOf("ok") >= 0;
                if (githubSearch.ready) {
                    identityProc.running = false;
                    identityProc.running = true;
                }
            }
        }
    }

    Process {
        id: identityProc
        running: false
        command: ["sh", "-c",
            "gh api user --jq .login 2>/dev/null; "
            + "gh api user/orgs --jq 'map(.login)|join(\",\")' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                githubSearch.userLogin = (lines[0] || "").trim();
                const orgsLine = (lines[1] || "").trim();
                githubSearch.userOrgs = orgsLine
                    ? orgsLine.split(",").filter(s => s.length > 0)
                    : [];
            }
        }
    }

    // 350ms debounce: slower than fd's 120ms because each keystroke
    // costs an HTTP round-trip to the GitHub search API, and the
    // rate-limit budget is per-token, not per-process.
    Timer {
        id: repositorySearchDebounce
        interval: 350
        repeat: false
        onTriggered: {
            const q = githubSearch.query.trim();
            if (!githubSearch.active || q.length === 0) {
                githubSearch.ownedRepositoryResults = [];
                githubSearch.globalRepositoryResults = [];
                return;
            }
            if (githubSearch.ownerFilter) {
                ownedRepositorySearchProc.command = ["gh", "search", "repos", q,
                                                     "--owner", githubSearch.ownerFilter,
                                                     "--json", "fullName,description,url,stargazersCount,language",
                                                     "--limit", "10"];
                ownedRepositorySearchProc.running = false;
                ownedRepositorySearchProc.running = true;
            } else {
                githubSearch.ownedRepositoryResults = [];
            }
            globalRepositorySearchProc.command = ["gh", "search", "repos", q,
                                                  "--json", "fullName,description,url,stargazersCount,language",
                                                  "--limit", "20"];
            globalRepositorySearchProc.running = false;
            globalRepositorySearchProc.running = true;
        }
    }

    function parseResults(text) {
        try { return JSON.parse(text || "[]"); } catch (_) { return []; }
    }

    Process {
        id: ownedRepositorySearchProc
        running: false
        command: ["gh"]
        stdout: StdioCollector {
            onStreamFinished: { githubSearch.ownedRepositoryResults = githubSearch.parseResults(this.text); }
        }
    }

    Process {
        id: globalRepositorySearchProc
        running: false
        command: ["gh"]
        stdout: StdioCollector {
            onStreamFinished: { githubSearch.globalRepositoryResults = githubSearch.parseResults(this.text); }
        }
    }

    Process {
        id: authoredPullRequestsProc
        running: false
        command: ["gh"]
        stdout: StdioCollector {
            onStreamFinished: { githubSearch.authoredPullRequestResults = githubSearch.parseResults(this.text); }
        }
    }
    Process {
        id: reviewRequestedPullRequestsProc
        running: false
        command: ["gh"]
        stdout: StdioCollector {
            onStreamFinished: { githubSearch.reviewRequestedPullRequestResults = githubSearch.parseResults(this.text); }
        }
    }
    Process {
        id: mentionedPullRequestsProc
        running: false
        command: ["gh"]
        stdout: StdioCollector {
            onStreamFinished: { githubSearch.mentionedPullRequestResults = githubSearch.parseResults(this.text); }
        }
    }
    Process {
        id: assignedPullRequestsProc
        running: false
        command: ["gh"]
        stdout: StdioCollector {
            onStreamFinished: { githubSearch.assignedPullRequestResults = githubSearch.parseResults(this.text); }
        }
    }

    Process {
        id: repositoryReadmeProc
        running: false
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: { githubSearch.previewText = this.text || "NO README"; }
        }
    }
}
