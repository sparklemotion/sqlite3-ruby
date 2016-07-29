#include <stdio.h>
#include <sqlite3_ruby.h>

VALUE cVTable;

/** structure for ruby virtual table: inherits from sqlite3_vtab */
typedef struct { 
	// mandatory sqlite3 fields
	const sqlite3_module* pModule;
	int nRef;
	char *zErrMsg;
	// Ruby fields
	VALUE vtable;
} ruby_sqlite3_vtab;

/** structure for ruby cursors: inherits from sqlite3_vtab_cursor */
typedef struct {
	ruby_sqlite3_vtab* pVTab;
	VALUE row;
	int rowid;
} ruby_sqlite3_vtab_cursor;

/**
 * lookup for a ruby class <ModuleName>::<TableName> and create an instance of this class
 * This instance is then used to bind sqlite vtab callbacks
 */
static int xCreate(sqlite3* db, VALUE *db_ruby,
		int argc, char **argv,
		ruby_sqlite3_vtab **ppVTab,
		char **pzErr)
{
	VALUE sql_stmt, tables;
	VALUE module_name, module;
	VALUE table_name, table;
	const char* module_name_cstr = (const char*)argv[0];
	const char* table_name_cstr = (const char*)argv[2];

	// method will raise in case of error: no need to use pzErr
	*pzErr = NULL;

	// lookup for hash db.vtables
	tables = rb_funcall(*db_ruby, rb_intern("vtables"), 0);
	if (!RB_TYPE_P(tables, T_HASH)) {
		rb_raise(rb_eTypeError, "xCreate: expect db.vtables to be a Hash");
	}
	module_name = rb_str_new2(module_name_cstr);
	module = rb_hash_aref(tables, module_name);
	if (module == Qnil ) {
		rb_raise(
			rb_eKeyError,
			"xCreate: module %s is declared in sqlite3 but cant be found in db.vtables.",
			module_name_cstr
			);
	}

	table_name = rb_str_new2(table_name_cstr);
	table = rb_hash_aref(module, table_name);
	if (table == Qnil) {
		rb_raise(
			rb_eKeyError,
			"no such table: %s in module %s",
			table_name_cstr,
			module_name_cstr
			);
	}
	if (rb_obj_is_kind_of(table, cVTable) != Qtrue) {
		VALUE table_inspect = rb_funcall(table, rb_intern("inspect"), 0);
		rb_raise(
			rb_eTypeError,
			"Object %s must inherit from VTable",
			StringValuePtr(table_inspect)
			);
	}

	// alloc a new ruby_sqlite3_vtab object
	// and store related attributes
	(*ppVTab) = (ruby_sqlite3_vtab*)malloc(sizeof(ruby_sqlite3_vtab));
	(*ppVTab)->vtable = table;

	// get the create statement
	sql_stmt = rb_funcall((*ppVTab)->vtable, rb_intern("create_statement"), 0);

#ifdef HAVE_RUBY_ENCODING_H
	if(!UTF8_P(sql_stmt)) {
		sql_stmt = rb_str_export_to_enc(sql_stmt, rb_utf8_encoding());
	}
#endif
	if ( sqlite3_declare_vtab(db, StringValuePtr(sql_stmt)) ) {
		rb_raise(rb_path2class("SQLite3::Exception"), "fail to declare virtual table with \"%s\": %s", StringValuePtr(sql_stmt), sqlite3_errmsg(db));
	}

	return SQLITE_OK;
}

static int xConnect(sqlite3* db, void *pAux,
		int argc, char **argv,
		ruby_sqlite3_vtab **ppVTab,
		char **pzErr)
{
	return xCreate(db, pAux, argc, argv, ppVTab, pzErr);
}

static VALUE constraint_op_as_symbol(unsigned char op)
{
	ID op_id;
	switch(op) {
		case SQLITE_INDEX_CONSTRAINT_EQ:
			op_id = rb_intern("==");
			break;
		case SQLITE_INDEX_CONSTRAINT_GT:
			op_id = rb_intern(">");
			break;
		case SQLITE_INDEX_CONSTRAINT_LE:
			op_id = rb_intern("<=");
			break;
		case SQLITE_INDEX_CONSTRAINT_LT:
			op_id = rb_intern("<");
			break;
		case SQLITE_INDEX_CONSTRAINT_GE:
			op_id = rb_intern(">=");
			break;
		case SQLITE_INDEX_CONSTRAINT_MATCH:
			op_id = rb_intern("match");
			break;
#if SQLITE_VERSION_NUMBER>=3010000
		case SQLITE_INDEX_CONSTRAINT_LIKE:
			op_id = rb_intern("like");
			break;
		case SQLITE_INDEX_CONSTRAINT_GLOB:
			op_id = rb_intern("glob");
			break;
		case SQLITE_INDEX_CONSTRAINT_REGEXP:
			op_id = rb_intern("regexp");
			break;
#endif
#if SQLITE_VERSION_NUMBER>=3009000
		case SQLITE_INDEX_SCAN_UNIQUE:
			op_id = rb_intern("unique");
			break;
#endif
		default:
			op_id = rb_intern("unsupported");
	}
	return ID2SYM(op_id);
}

static VALUE constraint_to_ruby(const struct sqlite3_index_constraint* c)
{
	VALUE cons = rb_ary_new2(2);
	rb_ary_store(cons, 0, LONG2FIX(c->iColumn));
	rb_ary_store(cons, 1, constraint_op_as_symbol(c->op));
	return cons;
}

static VALUE order_by_to_ruby(const struct sqlite3_index_orderby* c)
{
	VALUE order_by = rb_ary_new2(2);
	rb_ary_store(order_by, 0, LONG2FIX(c->iColumn));
	rb_ary_store(order_by, 1, LONG2FIX(1-2*c->desc));
	return order_by;
}

static int xBestIndex(ruby_sqlite3_vtab *pVTab, sqlite3_index_info* info)
{
	int i;
	VALUE constraint = rb_ary_new();
        VALUE order_by = rb_ary_new2(info->nOrderBy);
	VALUE ret, idx_num, estimated_cost, order_by_consumed, omit_all;
#if SQLITE_VERSION_NUMBER >= 3008002
	VALUE estimated_rows;
#endif
#if SQLITE_VERSION_NUMBER >= 3009000
	VALUE idx_flags;
#endif
#if SQLITE_VERSION_NUMBER >= 3010000
	VALUE col_used;
#endif

	// convert constraints to ruby
	for (i = 0; i < info->nConstraint; ++i) {
		if (info->aConstraint[i].usable) {
			rb_ary_push(constraint, constraint_to_ruby(info->aConstraint + i));
		} 
	}

	// convert order_by to ruby
	for (i = 0; i < info->nOrderBy; ++i) {
		rb_ary_store(order_by, i, order_by_to_ruby(info->aOrderBy + i));
	}

	ret = rb_funcall( pVTab->vtable, rb_intern("best_index"), 2, constraint, order_by );
	if (ret != Qnil ) {
		if (!RB_TYPE_P(ret, T_HASH)) {
			rb_raise(rb_eTypeError, "best_index: expect returned value to be a Hash");
		}
		idx_num = rb_hash_aref(ret, ID2SYM(rb_intern("idxNum")));
		if (idx_num == Qnil ) { 
			rb_raise(rb_eKeyError, "best_index: mandatory key 'idxNum' not found");
		}
		info->idxNum = FIX2INT(idx_num);
		estimated_cost = rb_hash_aref(ret, ID2SYM(rb_intern("estimatedCost")));
		if (estimated_cost != Qnil) { info->estimatedCost = NUM2DBL(estimated_cost); }
		order_by_consumed = rb_hash_aref(ret, ID2SYM(rb_intern("orderByConsumed")));
		info->orderByConsumed = RTEST(order_by_consumed);
#if SQLITE_VERSION_NUMBER >= 3008002
		estimated_rows = rb_hash_aref(ret, ID2SYM(rb_intern("estimatedRows")));
		if (estimated_rows != Qnil) { bignum_to_int64(estimated_rows, &info->estimatedRows); }
#endif
#if SQLITE_VERSION_NUMBER >= 3009000
		idx_flags = rb_hash_aref(ret, ID2SYM(rb_intern("idxFlags")));
		if (idx_flags != Qnil) { info->idxFlags = FIX2INT(idx_flags); }
#endif
#if SQLITE_VERSION_NUMBER >= 3010000
		col_used = rb_hash_aref(ret, ID2SYM(rb_intern("colUsed")));
		if (col_used != Qnil) { bignum_to_int64(col_used, &info->colUsed); }
#endif

		// make sure that expression are given to filter
		omit_all = rb_hash_aref(ret, ID2SYM(rb_intern("omitAllConstraint")));
		for (i = 0; i < info->nConstraint; ++i) {
			if (RTEST(omit_all)) {
				info->aConstraintUsage[i].omit = 1;
			}
			if (info->aConstraint[i].usable) {
				info->aConstraintUsage[i].argvIndex = (i+1);
			}
		}
	}

	return SQLITE_OK;
}

static int xDestroy(ruby_sqlite3_vtab *pVTab)
{
	free(pVTab);
	return SQLITE_OK;
}

static int xDisconnect(ruby_sqlite3_vtab *pVTab)
{
	return xDestroy(pVTab);
}

static int xOpen(ruby_sqlite3_vtab *pVTab, ruby_sqlite3_vtab_cursor **ppCursor)
{
	rb_funcall( pVTab->vtable, rb_intern("open"), 0 );
	*ppCursor = (ruby_sqlite3_vtab_cursor*)malloc(sizeof(ruby_sqlite3_vtab_cursor));
	(*ppCursor)->pVTab = pVTab;
	(*ppCursor)->rowid = 0;
	return SQLITE_OK;
}

static int xClose(ruby_sqlite3_vtab_cursor* cursor)
{
	rb_funcall( cursor->pVTab->vtable, rb_intern("close"), 0 );
	free(cursor);
	return SQLITE_OK;
}

static int xNext(ruby_sqlite3_vtab_cursor* cursor)
{
	cursor->row = rb_funcall(cursor->pVTab->vtable, rb_intern("next"), 0);
	++(cursor->rowid);
	return SQLITE_OK;
}

static int xFilter(ruby_sqlite3_vtab_cursor* cursor, int idxNum, const char *idxStr,
		int argc, sqlite3_value **argv)
{
	int i;
	VALUE argv_ruby = rb_ary_new2(argc);
	for (i = 0; i < argc; ++i) {
		rb_ary_store(argv_ruby, i, sqlite3val2rb(argv[i]));
	}
	rb_funcall( cursor->pVTab->vtable, rb_intern("filter"), 2,  LONG2FIX(idxNum), argv_ruby );
	cursor->rowid = 0;
	return xNext(cursor);
}

static int xEof(ruby_sqlite3_vtab_cursor* cursor)
{
	return (cursor->row == Qnil);
}

static int xColumn(ruby_sqlite3_vtab_cursor* cursor, sqlite3_context* context, int i)
{
	VALUE val = rb_ary_entry(cursor->row, i);
	set_sqlite3_func_result(context, val);
	return SQLITE_OK;
}

static int xRowid(ruby_sqlite3_vtab_cursor* cursor, sqlite_int64 *pRowid)
{
	*pRowid = cursor->rowid;
	return SQLITE_OK;
}

static sqlite3_module ruby_proxy_module =
{
	0,              /* iVersion */
	xCreate,        /* xCreate       - create a vtable */
	xConnect,       /* xConnect      - associate a vtable with a connection */
	xBestIndex,     /* xBestIndex    - best index */
	xDisconnect,    /* xDisconnect   - disassociate a vtable with a connection */
	xDestroy,       /* xDestroy      - destroy a vtable */
	xOpen,          /* xOpen         - open a cursor */
	xClose,         /* xClose        - close a cursor */
	xFilter,        /* xFilter       - configure scan constraints */
	xNext,          /* xNext         - advance a cursor */
	xEof,           /* xEof          - indicate end of result set*/
	xColumn,        /* xColumn       - read data */
	xRowid,         /* xRowid        - read data */
	NULL,           /* xUpdate       - write data */
	NULL,           /* xBegin        - begin transaction */
	NULL,           /* xSync         - sync transaction */
	NULL,           /* xCommit       - commit transaction */
	NULL,           /* xRollback     - rollback transaction */
	NULL,           /* xFindFunction - function overloading */
};

static VALUE create_module(VALUE self, VALUE db, VALUE name)
{
	VALUE *db_ruby;
	sqlite3RubyPtr db_ctx;
	StringValue(name);
	Data_Get_Struct(db, sqlite3Ruby, db_ctx);

	if(!db_ctx->db) {
		rb_raise(rb_eArgError, "create_module on a closed database");
	}

#ifdef HAVE_RUBY_ENCODING_H
	if(!UTF8_P(name)) {
		name = rb_str_export_to_enc(name, rb_utf8_encoding());
	}
#endif

	db_ruby = xcalloc(1, sizeof(VALUE));
	*db_ruby = db;
	if (sqlite3_create_module_v2(
			db_ctx->db,
			StringValuePtr(name),
			&ruby_proxy_module,
			db_ruby,
			xfree
			) != SQLITE_OK) {
		rb_raise(rb_path2class("SQLite3::Exception"), sqlite3_errmsg(db_ctx->db));
	}

	return Qnil;
}

void init_sqlite3_vtable()
{
	cVTable = rb_define_class_under(mSqlite3, "VTable", rb_cObject);
	rb_define_singleton_method(cVTable, "create_module", create_module, 2);
}

