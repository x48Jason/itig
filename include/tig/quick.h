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

#ifndef TIG_QUICK_H
#define TIG_QUICK_H

#include "tig/view.h"
#include "tig/graph.h"
#include "tig/util.h"

enum request quick_request(struct view *view, enum request request, struct line *line);

extern struct view quick_view;

static inline void
open_quick_view(struct view *prev, enum open_flags flags)
{
	open_view(prev, &quick_view, flags);
}

#endif
/* vim: set ts=8 sw=8 noexpandtab: */
