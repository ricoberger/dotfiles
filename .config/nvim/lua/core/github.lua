--------------------------------------------------------------------------------
-- UTILS
--------------------------------------------------------------------------------

-- Define icons for GitHub.
local icons = {
  github = {
    unknown = "",
    pr = "",
    issue = "",
    release = "",
    workflow = "",
    commit = "",
    gist = "",
    discussion = "",
  },
  notifications = {
    unread = "",
    read = "",
  },
  githubchecks = {
    success = "",
    failed = "✖",
    pending = "",
    done = "",
  },
}

-- Convert ISO 8601 timestamp to relative time
--
-- See: https://github.com/folke/snacks.nvim/blob/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/gh/item.lua#L15
-- See: https://github.com/folke/snacks.nvim/blob/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/picker/util/init.lua#L414
local function format_relative_time(s)
  local year, month, day, hour, min, sec =
    s:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z$")
  if not year then
    return
  end
  local t = os.time({
    year = assert(tonumber(year), "invalid year in timestamp: " .. s),
    month = assert(tonumber(month), "invalid month in timestamp: " .. s),
    day = assert(tonumber(day), "invalid day in timestamp: " .. s),
    hour = assert(tonumber(hour), "invalid hour in timestamp: " .. s),
    min = assert(tonumber(min), "invalid minute in timestamp: " .. s),
    sec = assert(tonumber(sec), "invalid second in timestamp: " .. s),
    isdst = false,
  })

  -- Calculate UTC offset
  local now = os.time()
  local utc_date = os.date("!*t", now)
  utc_date.isdst = false
  local time = t + os.difftime(now, os.time(utc_date))

  local delta = os.time() - time
  local tpl = {
    { 1, 60, "just now", "just now" },
    { 60, 3600, "a minute ago", "%d minutes ago" },
    { 3600, 3600 * 24, "an hour ago", "%d hours ago" },
    { 3600 * 24, 3600 * 24 * 7, "yesterday", "%d days ago" },
    { 3600 * 24 * 7, 3600 * 24 * 7 * 4, "a week ago", "%d weeks ago" },
  }
  for _, v in ipairs(tpl) do
    if delta < v[2] then
      local value = math.floor(delta / v[1] + 0.5)
      return value == 1 and v[3] or v[4]:format(value)
    end
  end
  if os.date("%Y", time) == os.date("%Y") then
    return os.date("%b %d", time)
  end
  return os.date("%b %d, %Y", time)
end

--------------------------------------------------------------------------------
-- GITHUB NOTIFICATIONS
--------------------------------------------------------------------------------

-- Fetch notifications from GitHub and show them via the Snacks picker. Issues
-- and PRs can be opened via Snacks. Discussions are opened in the browser.
vim.api.nvim_create_user_command("GitHubNotifications", function(opts)
  -- Fetch notifications from GitHub using the "gh" command-line tool and handle
  -- any errors.
  local output =
    vim.fn.system(string.format("gh-notifications '%s'", opts.args))

  if vim.v.shell_error ~= 0 then
    vim.notify(
      "Failed to fetch notifications: " .. output,
      vim.log.levels.ERROR
    )
    return
  end

  local ok, notifications = pcall(vim.fn.json_decode, output)
  if not ok or type(notifications) ~= "table" then
    vim.notify("Failed to parse notifications", vim.log.levels.ERROR)
    return
  end

  if #notifications == 0 then
    vim.notify("No notifications found", vim.log.levels.INFO)
    return
  end

  -- Prepare the items for the Snacks picker and format them nicely.
  local items = {}
  for idx, notification in ipairs(notifications) do
    local item = notification
    item.idx = idx
    item.relativeLastUpdatedAt = format_relative_time(item.lastUpdatedAt)
    item.repo = item.url:match("github.com/([^/]+/[^/]+)")
    item.text = item.subject.__typename .. " " .. item.repo .. " " .. item.title
    item.preview = {
      text = item.summaryItemBody,
      ft = "markdown",
    }
    table.insert(items, item)
  end

  -- Open the Snacks picker with the formatted notification items and format the
  -- items nicely.
  Snacks.picker({
    title = string.format("GitHub Notifications (%s)", opts.args),
    layout = {
      preset = "default",
      preview = false,
    },
    preview = "preview",
    items = items,
    format = function(item, _)
      local icon = { icons.notifications.read, "GitHubRead" }
      if item.isUnread then
        icon = { icons.notifications.unread, "GitHubRead" }
      end

      local type_icon = { icons.github.unknown, "GitHubTextSecondary" }
      if item.subject.__typename == "PullRequest" then
        type_icon = { icons.github.pr, "GitHubTextSecondary" }
        if item.subject.pullRequestState ~= nil then
          if item.subject.pullRequestState == "CLOSED" then
            type_icon = { icons.github.pr, "GitHubUnmerged" }
          elseif item.subject.isDraft then
            type_icon = { icons.github.pr, "GitHubTextSecondary" }
          elseif item.subject.pullRequestState == "OPEN" then
            type_icon = { icons.github.pr, "GitHubOpen" }
          elseif item.subject.pullRequestState == "MERGED" then
            type_icon = { icons.github.pr, "GitHubMerged" }
          end
        end
      elseif item.subject.__typename == "Issue" then
        type_icon = { icons.github.issue, "GitHubTextSecondary" }
        if item.subject.issueState ~= nil then
          if item.subject.issueState == "OPEN" then
            type_icon = { icons.github.issue, "GitHubOpen" }
          elseif item.subject.issueState == "CLOSED" then
            type_icon = { icons.github.issue, "GitHubClosed" }
          end
        end
      elseif item.subject.__typename == "Release" then
        type_icon = { icons.github.release, "GitHubTextSecondary" }
      elseif item.subject.__typename == "WokflowRun" then
        type_icon = { icons.github.workflow, "GitHubCheckFailed" }
      elseif item.subject.__typename == "CheckSuite" then
        if item.subject.conclusion == "SUCCESS" then
          type_icon = { icons.github.workflow, "GitHubCheckSuccess" }
        else
          type_icon = { icons.github.workflow, "GitHubCheckFailed" }
        end
      elseif item.subject.__typename == "Commit" then
        type_icon = { icons.github.commit, "GitHubTextSecondary" }
      elseif item.subject.__typename == "Gist" then
        type_icon = { icons.github.gist, "GitHubTextSecondary" }
      elseif item.subject.__typename == "TeamDiscussion" then
        type_icon = { icons.github.discussion, "GitHubTextSecondary" }
      elseif item.subject.__typename == "Discussion" then
        type_icon = { icons.github.discussion, "GitHubTextSecondary" }
      end

      return {
        icon,
        { " ", "GitHubTextSecondary" },
        type_icon,
        { " [", "GitHubTextSecondary" },
        { item.subject.__typename, "GitHubTextHighlight" },
        { "] " .. item.repo .. ": ", "GitHubTextSecondary" },
        { item.title, "GitHubText" },
        {
          " ("
            .. item.reason:lower():gsub("_", " ")
            .. " - "
            .. item.relativeLastUpdatedAt
            .. ")",
          "GitHubTextSecondary",
        },
      }
    end,
    confirm = function(picker, item)
      picker:close()

      -- If the item is an issue or pull request, we try to open it via Snacks,
      -- otherwise we open it in the browser.
      if item.subject.__typename == "Issue" then
        Snacks.picker.gh_issue({
          repo = item.repo,
          search = string.format("#%s", item.subject.number),
        })
      elseif item.subject.__typename == "PullRequest" then
        Snacks.picker.gh_pr({
          repo = item.repo,
          search = string.format("#%s", item.subject.number),
        })
      else
        vim.fn.system(string.format("open '%s'", item.url))
      end
    end,
    actions = {
      picker_yank_url = function(_, item)
        if not item then
          return
        end

        vim.fn.setreg("+", item.url)
        vim.notify("Yanked " .. item.url, vim.log.levels.INFO)
      end,
      picker_mark_as_read = function(picker, item)
        if not item then
          return
        end

        local sel = picker:selected()
        local selitems = #sel > 0 and sel or { item }

        for _, selitem in ipairs(selitems) do
          local readoutput = vim.fn.system(
            string.format(
              "gh api graphql -F notificationId=\"%s\" --raw-field query='mutation($notificationId: ID!) { markNotificationAsRead(input: {id: $notificationId}) { success } }'",
              selitem.id
            )
          )
          if vim.v.shell_error ~= 0 then
            vim.notify(
              "Failed to mark notification as read: " .. readoutput,
              vim.log.levels.ERROR
            )
            return
          end

          vim.notify(
            "Marked notification as read: " .. selitem.title,
            vim.log.levels.INFO
          )
        end
      end,
      picker_mark_as_unread = function(picker, item)
        if not item then
          return
        end

        local sel = picker:selected()
        local selitems = #sel > 0 and sel or { item }

        for _, selitem in ipairs(selitems) do
          local readoutput = vim.fn.system(
            string.format(
              "gh api graphql -F notificationId=\"%s\" --raw-field query='mutation($notificationId: ID!) { markNotificationAsUnread(input: {id: $notificationId}) { success } }'",
              selitem.id
            )
          )
          if vim.v.shell_error ~= 0 then
            vim.notify(
              "Failed to mark notification as unread: " .. readoutput,
              vim.log.levels.ERROR
            )
            return
          end

          vim.notify(
            "Marked notification as unread " .. selitem.title,
            vim.log.levels.INFO
          )
        end
      end,
      picker_mark_as_done = function(picker, item)
        if not item then
          return
        end

        local sel = picker:selected()
        local selitems = #sel > 0 and sel or { item }

        for _, selitem in ipairs(selitems) do
          local readoutput = vim.fn.system(
            string.format(
              "gh api graphql -F notificationId=\"%s\" --raw-field query='mutation($notificationId: ID!) { markNotificationAsDone(input: {id: $notificationId}) { success } }'",
              selitem.id
            )
          )
          if vim.v.shell_error ~= 0 then
            vim.notify(
              "Failed to mark notification as done: " .. readoutput,
              vim.log.levels.ERROR
            )
            return
          end

          vim.notify(
            "Marked notification as done: " .. selitem.title,
            vim.log.levels.INFO
          )
        end
      end,
      picker_mark_as_undone = function(picker, item)
        if not item then
          return
        end

        local sel = picker:selected()
        local selitems = #sel > 0 and sel or { item }

        for _, selitem in ipairs(selitems) do
          local readoutput = vim.fn.system(
            string.format(
              "gh api graphql -F notificationId=\"%s\" --raw-field query='mutation($notificationId: ID!) { markNotificationAsUndone(input: {id: $notificationId}) { success } }'",
              selitem.id
            )
          )
          if vim.v.shell_error ~= 0 then
            vim.notify(
              "Failed to mark notification as undone: " .. readoutput,
              vim.log.levels.ERROR
            )
            return
          end

          vim.notify(
            "Marked notification as undone: " .. selitem.title,
            vim.log.levels.INFO
          )
        end
      end,
      picker_change_cwd_to_repo = function(picker, item)
        if not item then
          return
        end

        local repository_path = "/Users/ricoberger/Documents/GitHub/"
          .. item.repo:lower()
        vim.api.nvim_set_current_dir(repository_path)

        vim.notify(
          "Current working directory was changed to: " .. repository_path,
          vim.log.levels.INFO
        )

        picker:close()
      end,
      picker_browse_url = function(_, item)
        vim.fn.jobstart({ "open", item.url }, { detach = true })
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-y>"] = { "picker_yank_url", mode = { "n", "i" } },
          ["<a-b>"] = { "picker_browse_url", mode = { "n", "i" } },
          ["<a-r>"] = { "picker_mark_as_read", mode = { "n", "i" } },
          ["<a-R>"] = { "picker_mark_as_unread", mode = { "n", "i" } },
          ["<a-d>"] = { "picker_mark_as_done", mode = { "n", "i" } },
          ["<a-D>"] = { "picker_mark_as_undone", mode = { "n", "i" } },
          ["<a-c>"] = { "picker_change_cwd_to_repo", mode = { "n", "i" } },
        },
      },
      list = {
        keys = {
          ["y"] = { "picker_yaml_url", mode = { "n", "x" } },
          ["b"] = { "picker_browse_url", mode = { "n", "i" } },
          ["r"] = { "picker_mark_as_read", mode = { "n", "x" } },
          ["R"] = { "picker_mark_as_unread", mode = { "n", "x" } },
          ["d"] = { "picker_mark_as_done", mode = { "n", "x" } },
          ["D"] = { "picker_mark_as_undone", mode = { "n", "x" } },
          ["c"] = { "picker_change_cwd_to_repo", mode = { "n", "x" } },
        },
      },
    },
  })
end, {
  nargs = "*",
})

--------------------------------------------------------------------------------
-- GITHUB SEARCH
--------------------------------------------------------------------------------

-- Fetch search results from GitHub and show them via the Snacks picker. Issues
-- and PRs are opened via Snacks.
vim.api.nvim_create_user_command("GitHubSearch", function(opts)
  -- Fetch search results from GitHub using the "gh" command-line tool and
  -- handle any errors.
  local output = vim.fn.system(
    string.format(
      "gh search issues --include-prs --limit 100 --json author,body,isPullRequest,number,repository,state,title,updatedAt,url %s",
      opts.args
    )
  )
  if vim.v.shell_error ~= 0 then
    vim.notify(
      "Failed to fetch search results: " .. output,
      vim.log.levels.ERROR
    )
    return
  end

  local ok, results = pcall(vim.fn.json_decode, output)
  if not ok or type(results) ~= "table" then
    vim.notify("Failed to parse search results", vim.log.levels.ERROR)
    return
  end

  if #results == 0 then
    vim.notify("No search results found", vim.log.levels.INFO)
    return
  end

  -- Prepare the items for the Snacks picker and format them nicely.
  local items = {}
  for idx, result in ipairs(results) do
    local item = result
    item.idx = idx
    item.relativeUpdatedAt = format_relative_time(item.updatedAt)
    item.text = " #"
      .. item.number
      .. " "
      .. item.repository.nameWithOwner
      .. " "
      .. item.title
      .. " "
      .. item.author.login
    item.preview = {
      text = item.body,
      ft = "markdown",
    }
    table.insert(items, item)
  end

  -- Open the Snacks picker with the formatted search result items and format
  -- the items nicely.
  Snacks.picker({
    title = string.format("GitHub Search Results (%s)", opts.args),
    layout = {
      preset = "default",
      preview = false,
    },
    preview = "preview",
    items = items,
    format = function(item, _)
      local type_icon = { icons.github.unknown, "GitHubTextSecondary" }
      if item.isPullRequest then
        if item.state == "open" then
          type_icon = { icons.github.pr, "GitHubOpen" }
        elseif item.state == "closed" then
          type_icon = { icons.github.pr, "GitHubUnmerged" }
        elseif item.state == "merged" then
          type_icon = { icons.github.pr, "GitHubMerged" }
        end
      else
        if item.state == "open" then
          type_icon = { icons.github.issue, "GitHubOpen" }
        elseif item.state == "closed" then
          type_icon = { icons.github.issue, "GitHubClosed" }
        end
      end

      return {
        type_icon,
        { " [", "GitHubTextSecondary" },
        { "#" .. item.number, "GitHubTextHighlight" },
        {
          "] " .. item.repository.nameWithOwner .. ": ",
          "GitHubTextSecondary",
        },
        { item.title, "GitHubText" },
        {
          " (" .. item.author.login .. " - " .. item.relativeUpdatedAt .. ")",
          "GitHubTextSecondary",
        },
      }
    end,
    confirm = function(picker, item)
      picker:close()

      if item.isPullRequest then
        Snacks.picker.gh_pr({
          repo = item.repository.nameWithOwner,
          search = string.format("#%s", item.number),
        })
      else
        Snacks.picker.gh_issue({
          repo = item.repository.nameWithOwner,
          search = string.format("#%s", item.number),
        })
      end
    end,
    actions = {
      picker_yank_url = function(_, item)
        if not item then
          return
        end

        vim.fn.setreg("+", item.url)
        vim.notify("Yanked " .. item.url, vim.log.levels.INFO)
      end,
      picker_change_cwd_to_repo = function(picker, item)
        if not item then
          return
        end

        local repository_path = "/Users/ricoberger/Documents/GitHub/"
          .. item.repository.nameWithOwner:lower()
        vim.api.nvim_set_current_dir(repository_path)

        vim.notify(
          "Current working directory was changed to: " .. repository_path,
          vim.log.levels.INFO
        )

        picker:close()
      end,
      picker_browse_url = function(_, item)
        vim.fn.jobstart({ "open", item.url }, { detach = true })
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-y>"] = { "picker_yank_url", mode = { "n", "i" } },
          ["<a-b>"] = { "picker_browse_url", mode = { "n", "i" } },
          ["<a-c>"] = { "picker_change_cwd_to_repo", mode = { "n", "i" } },
        },
      },
      list = {
        keys = {
          ["y"] = { "picker_yaml_url", mode = { "n", "x" } },
          ["b"] = { "picker_browse_url", mode = { "n", "i" } },
          ["c"] = { "picker_change_cwd_to_repo", mode = { "n", "x" } },
        },
      },
    },
  })
end, {
  nargs = "*",
})

--------------------------------------------------------------------------------
-- GITHUB CHECKS
--------------------------------------------------------------------------------

-- Fetch checks for the currently open PR and shows them in a Snacks picker. If
-- a check in the picker is selected we can view the logs of the check.
vim.api.nvim_create_user_command("GitHubChecks", function()
  -- Buffer name is: gh://owner/repo/pr/number
  local buffer = vim.fn.expand("%")
  local repo = buffer:match("gh://([^/]+/[^/]+)/pr/%d+")
  local pr_number = buffer:match("gh://[^/]+/[^/]+/pr/(%d+)")

  -- Fetch checks for PR from GitHub using the "gh" command-line tool and handle
  -- any errors.
  local output = vim.fn.system(
    string.format(
      "gh pr checks %s --repo %s --json bucket,completedAt,link,name,startedAt,state,workflow",
      pr_number,
      repo
    )
  )
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to fetch checks: " .. output, vim.log.levels.ERROR)
    return
  end

  local ok, results = pcall(vim.fn.json_decode, output)
  if not ok or type(results) ~= "table" then
    vim.notify("Failed to parse checks", vim.log.levels.ERROR)
    return
  end

  if #results == 0 then
    vim.notify("No checks found", vim.log.levels.INFO)
    return
  end

  -- Prepare the items for the Snacks picker and format them nicely.
  local items = {}
  for idx, result in ipairs(results) do
    local item = result
    item.idx = idx
    if item.workflow ~= "" then
      item.text = item.workflow .. " / " .. item.name
    else
      item.text = item.name
    end
    item.preview = {
      text = "",
      ft = "markdown",
    }
    table.insert(items, item)
  end

  -- Open the Snacks picker with the formatted check items and format the items
  -- nicely.
  Snacks.picker({
    title = string.format("GitHub Checks (#%s in %s)", pr_number, repo),
    layout = {
      preset = "default",
      preview = false,
    },
    preview = "preview",
    items = items,
    format = function(item, _)
      local state_icon = { icons.githubchecks.pending, "GitHubTextSecondary" }
      if
        item.state == "EXPECTED"
        or item.state == "IN_PROGRESS"
        or item.state == "QUEUED"
        or item.state == "REQUESTED"
        or item.state == "PENDING"
        or item.state == "WAITING"
      then
        state_icon = { icons.githubchecks.pending, "GitHubCheckPending" }
      elseif item.state == "FAILURE" or item.state == "STARTUP_FAILURE" then
        state_icon = { icons.githubchecks.failed, "GitHubCheckFailed" }
      else
        if item.state == "SUCCESS" then
          state_icon = { icons.githubchecks.success, "GitHubCheckSuccess" }
        elseif item.state == "SKIPPED" or item.state == "NEUTRAL" then
          state_icon = { icons.githubchecks.done, "GitHubTextSecondary" }
        else
          state_icon = { icons.githubchecks.failed, "GitHubCheckFailed" }
        end
      end

      return {
        state_icon,
        { " " .. item.text, "GitHubText" },
      }
    end,
    confirm = function(picker, item)
      picker:close()

      -- Get the job id from the link, e.g.
      -- https://github.com/kubenav/kubenav/actions/runs/20692497976/job/59402584382
      -- then fetch the summary and logs for the jobs.
      local job_id = item.link:match("/job/(%d+)$")
      local summary = vim.fn.system(
        string.format("gh run view --repo %s --job %s", repo, job_id)
      )
      local logs = vim.fn.system(
        string.format("gh run view --repo %s --job %s --log", repo, job_id)
      )

      -- Open a new vertical split and show the summary and logs of the jobs.
      vim.api.nvim_command(string.format("vsplit %s", job_id))
      vim.api.nvim_put(vim.split(summary, "\n"), "", true, true)
      vim.api.nvim_put({ "", "", "" }, "", true, true)
      vim.api.nvim_put(vim.split(logs, "\n"), "", true, true)
    end,
    actions = {
      picker_yank_url = function(_, item)
        if not item then
          return
        end

        vim.fn.setreg("+", item.link)
        vim.notify("Yanked " .. item.link, vim.log.levels.INFO)
      end,
      picker_browse_url = function(_, item)
        vim.fn.jobstart({ "open", item.link }, { detach = true })
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-y>"] = { "picker_yank_url", mode = { "n", "i" } },
          ["<a-b>"] = { "picker_browse_url", mode = { "n", "i" } },
        },
      },
      list = {
        keys = {
          ["y"] = { "picker_yank_url", mode = { "n", "x" } },
          ["b"] = { "picker_browse_url", mode = { "n", "i" } },
        },
      },
    },
  })
end, {
  nargs = "*",
})

--------------------------------------------------------------------------------
-- GITHUB MERGE
--------------------------------------------------------------------------------

-- Merge the currently open pull request via the "gh-pr-merge" command. Can be
-- used instead of the Snacks action to squash and merge the pull request with
-- admin privileges.
vim.api.nvim_create_user_command("GitHubMerge", function()
  -- Buffer name is: gh://owner/repo/pr/number
  local buffer = vim.fn.expand("%")
  local repo = buffer:match("gh://([^/]+/[^/]+)/pr/%d+")
  local pr_number = buffer:match("gh://[^/]+/[^/]+/pr/(%d+)")

  local output =
    vim.fn.system(string.format("gh-pr-merge %s %s ", pr_number, repo))
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to merge pull request: " .. output, vim.log.levels.ERROR)
    return
  else
    vim.notify(
      string.format("Pull request #%s in %s was merged", pr_number, repo),
      vim.log.levels.INFO
    )
  end
end, {
  nargs = "*",
})

--------------------------------------------------------------------------------
-- GITHUB PR
--------------------------------------------------------------------------------

vim.api.nvim_create_user_command("GitHubPr", function(opts)
  if not opts.args or opts.args == "" then
    local output = vim.fn.system(
      "gh pr view --json headRepository,headRepositoryOwner,number"
    )
    local _, pr = pcall(vim.fn.json_decode, output)
    Snacks.picker.gh_pr({
      repo = string.format(
        "%s/%s",
        pr.headRepositoryOwner.login,
        pr.headRepository.name
      ),
      search = string.format("#%s", pr.number),
    })
  else
    local repo, number = opts.args:match("([^%s]+)%s+(%d+)")
    Snacks.picker.gh_pr({ repo = repo, search = string.format("#%s", number) })
  end
end, {
  nargs = "*",
})

--------------------------------------------------------------------------------
-- GITHUB ISSUE
--------------------------------------------------------------------------------

vim.api.nvim_create_user_command("GitHubIssue", function(opts)
  local repo, number = opts.args:match("([^%s]+)%s+(%d+)")
  Snacks.picker.gh_issue({ repo = repo, search = string.format("#%s", number) })
end, {
  nargs = "*",
})
