/* -*- Mode: C; c-basic-offset:4 ; indent-tabs-mode:nil ; -*- */
/*
 * See COPYRIGHT in top-level directory.
 */

#ifndef _ZM_MULTQUEUE_H
#define _ZM_MULTQUEUE_H
#include <stdlib.h>
#include <stdio.h>
#include "queue/zm_queue_types.h"

/* glqueue: concurrent queue where both enqueue and dequeue operations
 * are protected with the same global lock (thus, the gl prefix) */

int zm_multqueue_init(zm_multqueue_t *);
int zm_multqueue_enqueue(zm_multqueue_t* q, void *data);
int zm_multqueue_dequeue(zm_multqueue_t* q, void **data);

#endif /* _ZM_MULTQUEUE_H */
