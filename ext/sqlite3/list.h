#ifndef SQLITE3_LIST_RUBY
#define SQLITE3_LIST_RUBY

#include <assert.h>

/* A simple doubly-linked list implementation with a sentinel node.
 *
 * Linked-Lists are tricky and this implementation aims to be easy for a
 * programmer to check and protect against most kinds of API-abuse with
 * assertions. It is inspired by the linux/list.h, but avoids macros and
 * offsetof(). Iteration is done via an explicti iterator instead of a
 * FOREACH macro.
 *
 * General use:
 * You have some "owner" or "parent" structure that holds/owns the list:
 *
 * struct parent {
 *   // other stuff
 *   rb_sqlite3_list_head_t foo_list;
 *   // more other stuff
 * };
 *
 * and a struct for the "foo" list (child) elements
 *
 * struct foo {
 *    rb_sqlite3_list_elem list;
 *    // other stuff
 * };
 *
 * I recommend putting the rb_sqlite3_list_elem first in the child so you can
 * freely cast between struct foo* and rb_sqlite3_list_elem*. If you put
 * rb_sqlite3_list_elem somewhere else you need to do the offsetof calculation
 * yourself.
 *
 * Make sure that both struct parent and struct foo do not move in memory, e.g.
 * allocate on the heap.
 * Also make sure that you initialize both the rb_sqlite3_list_head_t and
 * the rb_sqlite3_list_elem_t before doing anything else with them.
 *
 * The generic clear_list operation looks like:
 *
 * rb_sqlite3_list_iter_t iter = rb_sqlite3_list_iter_new(&parent->head);
 * rb_sqlite3_list_elem_t *e;
 * while ((e = rb_sqlite3_list_iter_step(&iter))) {
 *   rb_sqlite3_list_remove(e);
 *   free(e);
 * }
 *
 * The rest should be clear from the per-function comments below.
 */

typedef struct rb_sqlite3_list_elem
{
  struct rb_sqlite3_list_elem* next;
  struct rb_sqlite3_list_elem* prev;
} rb_sqlite3_list_elem_t;

/* the head is a sentinel node, it dos not hold any data and should be placed
 * into the object that "owns" the linked list. This struct exists, so that
 * C's type system provides minimal protection against mixing up the head
 * and the ordinary element nodes */
typedef struct rb_sqlite3_list_head
{
  struct rb_sqlite3_list_elem elem;
} rb_sqlite3_list_head_t;

/* list iterators private data. Obtain a new iterator from
 * rb_sqlite3_list_iter_new(). Now call rb_sqlite3_list_iter_step() on it
 * until it returns NULL */
typedef struct rb_sqlite3_list_iter
{
  struct rb_sqlite3_list_head* head; /* immutable. Always points at head */
  struct rb_sqlite3_list_elem* next; /* returned by next invocation of step() */
} rb_sqlite3_list_iter_t;

/* initialize an element to the unconnected state. Should aways be the first
 * thing to do with a rb_sqlite3_list_elem_t. */
static inline void
rb_sqlite3_list_elem_init(rb_sqlite3_list_elem_t* elem)
{
  elem->prev = elem;
  elem->next = elem;
}

/* initialize a list head to the empty state. Should aways be the first
 * thing to do with a rb_sqlite3_list_head_t */
static inline void
rb_sqlite3_list_head_init(rb_sqlite3_list_head_t* head)
{
  rb_sqlite3_list_elem_init(&head->elem);
}

/* return true iff the the list is empty. That is the only member of the
 * list is the sentinel */
static inline int
rb_sqlite3_list_empty(rb_sqlite3_list_head_t* head)
{
  /* an unitialized list is neither empty nor occupied, so you may not call
   * list_empty on it */
  assert(head->elem.prev && head->elem.next);
  return head->elem.next == &head->elem;
}

/* consider this an internel helper function. Rather define additional
 * functions like rb_sqlite3_list_insert_after() or something like that
 * if you need this functionaliy */
static inline void
rb_sqlite3_list_insert_between(rb_sqlite3_list_elem_t* prev_element,
                               rb_sqlite3_list_elem_t* new_element,
                               rb_sqlite3_list_elem_t* next_element)
{
  /* detect uninitialized prev_element or next_element in the common case
   * that it is zero filled */
  assert(prev_element->prev && prev_element->next);
  assert(next_element->prev && next_element->next);

  /* next_element must actually be the successor of previous element */
  assert(prev_element->next == next_element);
  assert(next_element->prev == prev_element);

  /* our new_element must be in the initialized, unconnected state. This
   * is joust to protect from the mistake of inserting an already inserted
   * element into a second list, which would corrupt the first list */
  assert(new_element->prev == new_element);

  new_element->prev = prev_element;
  new_element->next = next_element;
  prev_element->next = new_element;
  next_element->prev = new_element;
}

/* insert new_element at the tail of the list. In other words insert
 * it before the head */
static inline void
rb_sqlite3_list_insert_tail(rb_sqlite3_list_head_t* head,
                            rb_sqlite3_list_elem_t* new_element)
{
  rb_sqlite3_list_insert_between(head->elem.prev, new_element, &head->elem);
}

/* remove this element from a list. Thanks to this being a doubly-linked list,
 * you don't need the head element of the list. Only elem itself and its
 * direct neighbours are involved */
static inline void
rb_sqlite3_list_remove(rb_sqlite3_list_elem_t* elem)
{
  rb_sqlite3_list_elem_t* prev = elem->prev;
  rb_sqlite3_list_elem_t* next = elem->next;

  /* this assertion triggers if elem is not part of a linked list and elso
   * detetcs zero-filled elem pointers */
  assert(prev && prev != elem);

  prev->next = next;
  next->prev = prev;

  /* avoid the common bug of reinserting uninitialized elems */
  rb_sqlite3_list_elem_init(elem);
}

/* obtain a new iterator. */
static inline rb_sqlite3_list_iter_t
rb_sqlite3_list_iter_new(rb_sqlite3_list_head_t* head)
{
  /* again check if head looks initalized */
  assert(head->elem.prev && head->elem.next);
  rb_sqlite3_list_iter_t iter = {.head = head, .next = head->elem.next };
  return iter;
}

/* Yield the next element from the iterator or NULL if at the end of the
 * list. Once iteration is complete, will always return NULL.
 * list step is safe in the sense that you may remove the returned element
 * from the list and free() it. DO NOT MODIFY THE LIST IN ANY OTHER WAY. */
static inline rb_sqlite3_list_elem_t*
rb_sqlite3_list_iter_step(rb_sqlite3_list_iter_t* iter)
{
  rb_sqlite3_list_elem_t* tmp = iter->next;

  if (iter->next == &iter->head->elem) {
    return NULL;
  }

  iter->next = iter->next->next;
  return tmp;
}

#endif
