/* Copyright (c) 2006-2022 Jonas Fonseca <jonas.fonseca@gmail.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

#include "tig/io.h"
#include "tig/repo.h"
#include "tig/options.h"
#include "tig/parse.h"
#include "tig/watch.h"
#include "tig/graph.h"
#include "tig/display.h"
#include "tig/view.h"
#include "tig/draw.h"
#include "tig/git.h"
#include "tig/status.h"
#include "tig/stage.h"
#include "tig/quick.h"
#include "tig/main.h"
#include "tig/diff.h"
#include "tig/search.h"
#include "tig/bplist.h"

static int quick_append_one_log(const char *hash, int fd)
{
	const char *argv[] = {
		"git", "show", "-s", hash, "--pretty=raw", "--date=raw", "--parents", "--no-color", NULL
	};

	return io_run_append_no_close(argv, fd);
}

static int quick_prepare_log(const char *argv[], const char *dir, const char *filename)
{
	char name[SIZEOF_STR] = "";
	int argc;
	int fd;

	snprintf(name, sizeof(name), "%s/%s", dir, filename);
	fd = open(name, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR);
	if (fd < 0)
		die("failed to open quick log file");

	if (argv == NULL) {
		io_trace("quick_prepare_log: argv == NULL\n");
		goto out;
	}

	for (argc = 0; argv[argc]; argc++) {
		const char *arg = argv[argc];

		io_trace("quick_prepare_log: append rev %s\n", arg);
		quick_append_one_log(arg, fd);
	}
out:
	close(fd);
	return 0;
}

static enum status_code
quick_open(struct view *view, enum open_flags flags)
{
	const char **argv = NULL;
	struct main_state *state = view->private;
	const char *dir = "/dev/shm/";
	char filename[SIZEOF_STR] = "";
	const char *quick_argv[] = { dir, filename, NULL };

	bplist_to_argv(&global_bplist, &argv);

	snprintf(filename, sizeof(filename), "quick-log-%d.pipe", getpid());
	quick_prepare_log(argv, dir, filename);

	state->with_graph = false;
	state->graph = NULL;

	/* This calls reset_view() so must be before adding changes commits. */
	return begin_update(view, dir, quick_argv, flags);
}

enum request
quick_request(struct view *view, enum request request, struct line *line)
{
	enum open_flags flags = (request != REQ_VIEW_DIFF &&
				 (view_is_displayed(view) ||
				  ((line->type == LINE_MAIN_COMMIT ||
				    line->type == LINE_MAIN_ANNOTATED) &&
				   !view_is_displayed(&diff_view)) ||
				  line->type == LINE_STAT_UNSTAGED ||
				  line->type == LINE_STAT_STAGED ||
				  line->type == LINE_STAT_UNTRACKED))
				? OPEN_SPLIT : OPEN_DEFAULT;

	switch (request) {
	case REQ_VIEW_DIFF:
	case REQ_ENTER:
		if ((view_is_displayed(view) && display[0] != view) ||
		    (!view_is_displayed(view) && flags == OPEN_SPLIT)) {
			maximize_view(view, true);
			if (view->parent)
				view->parent = NULL;
		}

		if (line->type == LINE_STAT_UNSTAGED
		    || line->type == LINE_STAT_STAGED)
			open_stage_view(view, NULL, line->type, flags);
		else if (line->type == LINE_STAT_UNTRACKED)
			open_status_view(view, true, flags);
		else
			open_diff_view(view, flags);
		break;

	case REQ_REFRESH:
		load_refs(true);
		refresh_view(view);
		break;

	default:
		return request;
	}

	return REQ_NONE;
}

static bool quick_get_select_range(struct view *view, long *from, long *to)
{
	struct select_range *r = &view->sel_range;

	if (r->state == select_in_progress) {
		r->end = view->pos.lineno;
		r->state = select_done;
	}
	if (r->state == select_done) {
		*from = (r->start > r->end) ? r->start : r->end;
		*to = (r->start < r->end) ? r->start : r->end;
		return true;
	}

	*from = view->lines - 1;
	*to = 0;
	return true;
}

static struct view_ops quick_ops = {
	"quick commit",
	argv_env.head,
	VIEW_SEND_CHILD_ENTER | VIEW_FILE_FILTER | VIEW_REV_FILTER | VIEW_LOG_LIKE | VIEW_REFRESH,
	sizeof(struct main_state),
	quick_open,
	main_read,
	view_column_draw,
	quick_request,
	view_column_grep,
	main_select,
	main_done,
	view_column_bit(AUTHOR) | view_column_bit(COMMIT_TITLE) |
		view_column_bit(DATE) |	view_column_bit(ID) |
		view_column_bit(LINE_NUMBER),
	main_get_column_data,
	quick_get_select_range,
};

DEFINE_VIEW(quick);

/* vim: set ts=8 sw=8 noexpandtab: */
