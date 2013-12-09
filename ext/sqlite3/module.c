#include <stdio.h>
#include <sqlite3_ruby.h>

VALUE cSqlite3Module;

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
static int xCreate(sqlite3* db, VALUE *module_name,
		int argc, char **argv,
		ruby_sqlite3_vtab **ppVTab,
		char **pzErr)
{
	VALUE sql_stmt, module, ruby_class;
	ID table_id, module_id;
	VALUE ruby_class_args[0];
	const char* module_name_cstr = (const char*)StringValuePtr(*module_name);
	const char* table_name_cstr = (const char*)argv[2];

	// lookup for ruby class named like <module_id>::<table_name>
	module_id = rb_intern( module_name_cstr );
	module = rb_const_get(rb_cObject, module_id);
	table_id = rb_intern( table_name_cstr );
	ruby_class = rb_const_get(module, table_id);

	// alloc a new ruby_sqlite3_vtab object
	// and store related attributes
	(*ppVTab) = (ruby_sqlite3_vtab*)malloc(sizeof(ruby_sqlite3_vtab));

	// create a new instance
	(*ppVTab)->vtable = rb_class_new_instance(0, ruby_class_args, ruby_class);

	// call the create function
	sql_stmt = rb_funcall((*ppVTab)->vtable, rb_intern("create_statement"), 0);

#ifdef HAVE_RUBY_ENCODING_H
	if(!UTF8_P(sql_stmt)) {
		sql_stmt = rb_str_export_to_enc(sql_stmt, rb_utf8_encoding());
	}
#endif
	if ( sqlite3_declare_vtab(db, StringValuePtr(sql_stmt)) )
		rb_raise(rb_eArgError, "fail to declare virtual table");

	return SQLITE_OK;
}

static int xConnect(sqlite3* db, void *pAux,
		int argc, char **argv,
		ruby_sqlite3_vtab **ppVTab,
		char **pzErr)
{
	return xCreate(db, pAux, argc, argv, ppVTab, pzErr);
}

static int xBestIndex(ruby_sqlite3_vtab *pVTab, sqlite3_index_info* info)
{
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

static void deallocate(void * ctx)
{
	sqlite3ModuleRubyPtr c = (sqlite3ModuleRubyPtr)ctx;
	xfree(c);
}

static VALUE allocate(VALUE klass)
{
	sqlite3ModuleRubyPtr ctx = xcalloc((size_t)1, sizeof(sqlite3ModuleRuby));
	ctx->module     = NULL;

	return Data_Wrap_Struct(klass, NULL, deallocate, ctx);
}

static VALUE initialize(VALUE self, VALUE db, VALUE name)
{
	sqlite3RubyPtr db_ctx;
	sqlite3ModuleRubyPtr ctx;

	StringValue(name);

	Data_Get_Struct(db, sqlite3Ruby, db_ctx);
	Data_Get_Struct(self, sqlite3ModuleRuby, ctx);


	if(!db_ctx->db)
		rb_raise(rb_eArgError, "initializing a module on a closed database");

#ifdef HAVE_RUBY_ENCODING_H
	if(!UTF8_P(name)) {
		name               = rb_str_export_to_enc(name, rb_utf8_encoding());
	}
#endif
	
	// make possible to access to ruby object from c
	ctx->module_name = name;

	sqlite3_create_module(
			db_ctx->db,
			(const char *)StringValuePtr(name),
			&ruby_proxy_module,
			&(ctx->module_name) //the vtable required the module name
			);

	return self;
}

void init_sqlite3_module()
{
	cSqlite3Module = rb_define_class_under(mSqlite3, "Module", rb_cObject);
	rb_define_alloc_func(cSqlite3Module, allocate);
	rb_define_method(cSqlite3Module, "initialize", initialize, 2);
}

