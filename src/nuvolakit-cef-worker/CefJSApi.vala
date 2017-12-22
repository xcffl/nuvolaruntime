/*
 * Copyright 2011-2017 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 * 
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer. 
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution. 
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

namespace Nuvola {

private const string SCRIPT_WRAPPER = """window.__nuvola_func__ = function() {
window.__nuvola_func__ = null;
if (this == window) throw Error("Nuvola object is not bound to 'this'.");
this._callIpcMethodVoid = function(){console.log("_callIpcMethodVoid called!")};
%s
;}
""";
private extern const int VERSION_MAJOR;
private extern const int VERSION_MINOR;
private extern const int VERSION_BUGFIX;
private extern const string VERSION_SUFFIX;

public class CefJSApi : GLib.Object {
	private const string MAIN_JS = "main.js";
	private const string META_JSON = "metadata.json";
	private const string META_PROPERTY = "meta";
	public const string JS_DIR = "js";
	/**
	 * Name of file with integration script.
	 */
	private const string INTEGRATE_JS = "integrate.js";
	/**
	 * Name of file with settings script.
	 */
	private const string SETTINGS_SCRIPT = "settings.js";
	/**
	 * Major version of the JavaScript API
	 */
	public const int API_VERSION_MAJOR = VERSION_MAJOR;
	public const int API_VERSION_MINOR = VERSION_MINOR;
	public const int API_VERSION = API_VERSION_MAJOR * 100 + API_VERSION_MINOR;
	
	private Drt.Storage storage;
	private File data_dir;
	private File config_dir;
	private Drt.KeyValueStorage[] key_value_storages;
	private uint[] webkit_version;
	private uint[] libsoup_version;
	private bool warn_on_sync_func;
	private Cef.V8context? v8_ctx = null;
	private Cef.V8value? main_object = null;
	
	public CefJSApi(Drt.Storage storage, File data_dir, File config_dir, Drt.KeyValueStorage config,
	Drt.KeyValueStorage session, uint[] webkit_version, uint[] libsoup_version, bool warn_on_sync_func) {
		this.storage = storage;
		this.data_dir = data_dir;
		this.config_dir = config_dir;
		this.key_value_storages = {config, session};
		assert(webkit_version.length >= 3);
		this.webkit_version = webkit_version;
		this.libsoup_version = libsoup_version;
		this.warn_on_sync_func = warn_on_sync_func;
	}
	
	public bool is_valid() {
		return v8_ctx != null;
	}
	
	public void inject(Cef.V8context v8_ctx) {
		if (this.v8_ctx != null) {
			this.v8_ctx.exit();
			this.v8_ctx = null;
		}
		assert(v8_ctx.is_valid() > 0);
		v8_ctx.enter();
		main_object = Cef.v8value_create_object(null, null);
		main_object.ref();
		Cef.V8.set_int(main_object, "API_VERSION_MAJOR", API_VERSION_MAJOR);
		Cef.V8.set_int(main_object, "API_VERSION_MINOR", API_VERSION_MINOR);
		Cef.V8.set_int(main_object, "API_VERSION", API_VERSION);
		Cef.V8.set_int(main_object, "VERSION_MAJOR", VERSION_MAJOR);
		Cef.V8.set_int(main_object, "VERSION_MINOR", VERSION_MINOR);
		Cef.V8.set_int(main_object, "VERSION_MICRO", VERSION_BUGFIX);
		Cef.V8.set_int(main_object, "VERSION_BUGFIX", VERSION_BUGFIX);
		Cef.V8.set_string(main_object, "VERSION_SUFFIX", VERSION_SUFFIX);
		Cef.V8.set_int(main_object, "VERSION", Nuvola.get_encoded_version());
		Cef.V8.set_uint(main_object, "WEBKITGTK_VERSION", get_webkit_version());
		Cef.V8.set_uint(main_object, "WEBKITGTK_MAJOR", webkit_version[0]);
		Cef.V8.set_uint(main_object, "WEBKITGTK_MINOR", webkit_version[1]);
		Cef.V8.set_uint(main_object, "WEBKITGTK_MICRO", webkit_version[2]);
		Cef.V8.set_uint(main_object, "LIBSOUP_VERSION", get_libsoup_version());
		Cef.V8.set_uint(main_object, "LIBSOUP_MAJOR", libsoup_version[0]);
		Cef.V8.set_uint(main_object, "LIBSOUP_MINOR", libsoup_version[1]);
		Cef.V8.set_uint(main_object, "LIBSOUP_MICRO", libsoup_version[2]);

		File? main_js = storage.user_data_dir.get_child(JS_DIR).get_child(MAIN_JS);
		if (!main_js.query_exists()) {
			main_js = null;
			foreach (var dir in storage.data_dirs) {
				main_js = dir.get_child(JS_DIR).get_child(MAIN_JS);
				if (main_js.query_exists()) {
					break;
				}
				main_js = null;
			}
		}
		
		if (main_js == null) {
			error("Failed to find a core component main.js. This probably means the application has not been installed correctly or that component has been accidentally deleted.");
		}
		this.v8_ctx = v8_ctx;
		if (!execute_script_from_file(main_js)) {
			error("Failed to initialize a core component main.js located at '%s'. Initialization exited with error:", main_js.get_path());
		}
		
		var meta_json = data_dir.get_child(META_JSON);
		if (!meta_json.query_exists()) {
			error("Failed to find a web app component %s. This probably means the web app integration has not been installed correctly or that component has been accidentally deleted.", META_JSON);
		}
		string meta_json_data;
		try {
			meta_json_data = Drt.System.read_file(meta_json);
		} catch (GLib.Error e) {
			error("Failed load a web app component %s. This probably means the web app integration has not been installed correctly or that component has been accidentally deleted.\n\n%s", META_JSON, e.message);
		}
		
		string? json_error = null; 
		var meta = Cef.V8.parse_json(v8_ctx, meta_json_data, out json_error);
		if (meta == null) {
			error(json_error);
		}
		Cef.V8.set_value(main_object, "meta", meta);
	}
	
	public void integrate(Cef.V8context v8_ctx) {
		var integrate_js = data_dir.get_child(INTEGRATE_JS);
		if (!integrate_js.query_exists()) {
			error("Failed to find a web app component %s. This probably means the web app integration has not been installed correctly or that component has been accidentally deleted.", INTEGRATE_JS);
		}
		if (!execute_script_from_file(integrate_js)) {
			error("Failed to initialize a web app component %s located at '%s'. Initialization exited with error:\n\n%s", INTEGRATE_JS, integrate_js.get_path(), "e.message");
		}
	}
	
	public void release_context(Cef.V8context v8_ctx) {
		if (v8_ctx == this.v8_ctx) {
			v8_ctx.exit();
			this.v8_ctx = null;
		}
	}
	
	public bool execute_script_from_file(File file) {
		string script;
		try {
			script = Drt.System.read_file(file);
		} catch (GLib.Error e) 	{
			error("Unable to read script %s: %s", file.get_path(), e.message);
		}
		return execute_script(script, file.get_uri(), 1);
	}
	
	public bool execute_script(string script, string path, int line) {
		assert(v8_ctx != null);
        Cef.String _script = {};
        var wrapped_script = SCRIPT_WRAPPER.printf(script).replace("\t", " ");
//~         stderr.puts(wrapped_script);
        Cef.set_string(&_script, wrapped_script);
        Cef.String _path = {};
        Cef.set_string(&_path, path);
        Cef.V8value? retval = null;
        Cef.V8exception? exception = null;
        var result = (bool) v8_ctx.eval(&_script, &_path, line, out retval, out exception);
        if (exception != null) {
			error(Cef.V8.format_exception(exception));
		}
		if (result) {
			var global_object = v8_ctx.get_global();
			var func = Cef.V8.get_function(global_object, "__nuvola_func__");
			assert(func != null);
			var ret_val = func.execute_function(main_object, {});
			if (ret_val == null) {
				result = false;
				error(Cef.V8.format_exception(func.get_exception()));
			} else {
				result = true;
			}
		}
        return result;
	}
	
	public uint get_webkit_version() {
		return webkit_version[0] * 10000 + webkit_version[1] * 100 + webkit_version[2];
	}
	
	public uint get_libsoup_version() {
		return libsoup_version[0] * 10000 + libsoup_version[1] * 100 + libsoup_version[2];
	}
}

} // namespace Nuvola