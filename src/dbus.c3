module wl_gamma;
import std::io;

excuse DBUS_INIT_FAILED, SERVER_ALREADY_RUNNING;

const ZString DBUS_SERVICE_NAME = "rs.wl-gammarelay";
const ZString DBUS_INTERFACE    = "rs.wl.gammarelay";

const int DBUS_BUS_SESSION = 0;

const uint DBUS_NAME_FLAG_DO_NOT_QUEUE = 0x4;
const int DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER = 1;

const int DBUS_MESSAGE_TYPE_METHOD_CALL   = 1;
const int DBUS_MESSAGE_TYPE_METHOD_RETURN = 2;
const int DBUS_MESSAGE_TYPE_ERROR         = 3;
const int DBUS_MESSAGE_TYPE_SIGNAL        = 4;

constdef DBusType : CInt
{
	BOOLEAN    = 'b',
	INT16      = 'n',
	UINT16     = 'q',
	DOUBLE     = 'd',
	STRING     = 's',
	ARRAY      = 'a',
	VARIANT    = 'v',
	DICT_ENTRY = 'e',
}

struct DBusConnection { void* _opaque; }
struct DBusMessage { void* _opaque; }

struct DBusError
{
	char* name;
	char* message;
	uint dummy1;
	uint dummy2;
	uint dummy3;
	uint dummy4;
	uint dummy5;
	void* padding1;
}

struct DBusMessageIter
{
	void* dummy1;
	void* dummy2;
	uint dummy3;
	int dummy4;
	int dummy5;
	int dummy6;
	int dummy7;
	int dummy8;
	int dummy9;
	int dummy10;
	int dummy11;
	int pad1;
	void* pad2;
	void* pad3;
}

extern fn void dbus_error_init(DBusError* error);
extern fn void dbus_error_free(DBusError* error);

extern fn DBusConnection* dbus_bus_get_private(int type, DBusError* error);
extern fn int dbus_bus_request_name(DBusConnection* connection, ZString name, uint flags, DBusError* error);
extern fn bool dbus_bus_name_has_owner(DBusConnection* connection, ZString name, DBusError* error);
extern fn void dbus_bus_add_match(DBusConnection* connection, ZString rule, DBusError* error);

extern fn int dbus_connection_get_unix_fd(DBusConnection* connection, int* fd);
extern fn bool dbus_connection_read_write(DBusConnection* connection, int timeout_milliseconds);
extern fn DBusMessage* dbus_connection_pop_message(DBusConnection* connection);
extern fn bool dbus_connection_send(DBusConnection* connection, DBusMessage* message, uint* client_serial);
extern fn DBusMessage* dbus_connection_send_with_reply_and_block(DBusConnection* connection, DBusMessage* message, int timeout_milliseconds, DBusError* error);
extern fn void dbus_connection_flush(DBusConnection* connection);
extern fn void dbus_connection_close(DBusConnection* connection);
extern fn void dbus_connection_unref(DBusConnection* connection);

extern fn DBusMessage* dbus_message_new_signal(ZString path, ZString iface, ZString name);
extern fn DBusMessage* dbus_message_new_method_call(ZString destination, ZString path, ZString iface, ZString method);
extern fn DBusMessage* dbus_message_new_method_return(DBusMessage* method_call);
extern fn DBusMessage* dbus_message_new_error(DBusMessage* reply_to, ZString error_name, ZString error_message);
extern fn void dbus_message_unref(DBusMessage* message);

extern fn int dbus_message_get_type(DBusMessage* message);
extern fn ZString dbus_message_get_path(DBusMessage* message);
extern fn ZString dbus_message_get_interface(DBusMessage* message);
extern fn ZString dbus_message_get_member(DBusMessage* message);

extern fn bool dbus_message_iter_init(DBusMessage* message, DBusMessageIter* iter);
extern fn void dbus_message_iter_init_append(DBusMessage* message, DBusMessageIter* iter);
extern fn DBusType dbus_message_iter_get_arg_type(DBusMessageIter* iter);
extern fn void dbus_message_iter_get_basic(DBusMessageIter* iter, void* value);
extern fn bool dbus_message_iter_next(DBusMessageIter* iter);
extern fn void dbus_message_iter_recurse(DBusMessageIter* iter, DBusMessageIter* sub);
extern fn bool dbus_message_iter_append_basic(DBusMessageIter* iter, DBusType type, void* value);
extern fn bool dbus_message_iter_open_container(DBusMessageIter* iter, DBusType type, char* contained_signature, DBusMessageIter* sub);
extern fn bool dbus_message_iter_close_container(DBusMessageIter* iter, DBusMessageIter* sub);

struct DbusServer
{
	DBusConnection* conn;
	int fd;
}

struct DbusClient
{
	DBusConnection* conn;
	int fd;
	String format;
	ushort temperature;
	double gamma;
	double brightness;
	ushort prev_temperature;
	double prev_gamma;
	double prev_brightness;
	bool initialized;
}

fn void append_dict_variant(DBusMessageIter* dict, ZString name, DBusType type, char* sig, void* val)
{
	DBusMessageIter entry;
	dbus_message_iter_open_container(dict, DICT_ENTRY, null, &entry);
	dbus_message_iter_append_basic(&entry, STRING, &name);

	DBusMessageIter variant_iter;
	dbus_message_iter_open_container(&entry, VARIANT, sig, &variant_iter);
	dbus_message_iter_append_basic(&variant_iter, type, val);
	dbus_message_iter_close_container(&entry, &variant_iter);

	dbus_message_iter_close_container(dict, &entry);
}

fn void dbus_server_signal_change(DbusServer* server, ZString path, ZString prop, DBusType type, char* sig, void* val)
{
	DBusMessage* signal = dbus_message_new_signal(path, "org.freedesktop.DBus.Properties", "PropertiesChanged");
	if (signal == null)
	{
		return;
	}
	defer dbus_message_unref(signal);

	DBusMessageIter iter;
	dbus_message_iter_init_append(signal, &iter);

	ZString iface = DBUS_INTERFACE;
	dbus_message_iter_append_basic(&iter, STRING, &iface);

	DBusMessageIter dict;
	dbus_message_iter_open_container(&iter, ARRAY, "{sv}", &dict);
	append_dict_variant(&dict, prop, type, sig, val);
	dbus_message_iter_close_container(&iter, &dict);

	DBusMessageIter arr;
	dbus_message_iter_open_container(&iter, ARRAY, "s", &arr);
	dbus_message_iter_close_container(&iter, &arr);

	dbus_connection_send(server.conn, signal, null);
	dbus_connection_flush(server.conn);
}

fn void dbus_server_signal_outputs(DbusServer* server, WaylandState* wl, ZString prop, DBusType type, char* sig, void* val)
{
	foreach (out : wl.outputs[:wl.output_count])
	{
		if (out != null && out.has_name && out.color_changed)
		{
			dbus_server_signal_change(server, (ZString)&out.dbus_path, prop, type, sig, val);
		}
	}
}

fn DbusServer*? dbus_server_init()
{
	DBusError err;
	dbus_error_init(&err);
	defer dbus_error_free(&err);

	DBusConnection* conn = dbus_bus_get_private(DBUS_BUS_SESSION, &err);
	if (conn == null)
	{
		return DBUS_INIT_FAILED~;
	}

	int res = dbus_bus_request_name(conn, DBUS_SERVICE_NAME, DBUS_NAME_FLAG_DO_NOT_QUEUE, &err);
	if (res != DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER)
	{
		dbus_connection_close(conn);
		dbus_connection_unref(conn);
		return SERVER_ALREADY_RUNNING~;
	}

	int fd = -1;
	dbus_connection_get_unix_fd(conn, &fd);

	DbusServer* server = mem::new(DbusServer);
	server.conn = conn;
	server.fd = fd;
	return server;
}

fn void dbus_server_destroy(DbusServer* server)
{
	if (server == null)
	{
		return;
	}
	if (server.conn != null)
	{
		dbus_connection_close(server.conn);
		dbus_connection_unref(server.conn);
	}
	mem::free(server);
}

fn ZString introspect_xml_root() =>
	"<!DOCTYPE node PUBLIC \"-//freedesktop//DTD D-BUS Object Introspection 1.0//EN\"\n"
	" \"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd\">\n"
	"<node>\n"
	"  <interface name=\"org.freedesktop.DBus.Introspectable\">\n"
	"    <method name=\"Introspect\">\n"
	"      <arg name=\"data\" type=\"s\" direction=\"out\"/>\n"
	"    </method>\n"
	"  </interface>\n"
	"  <interface name=\"org.freedesktop.DBus.Properties\">\n"
	"    <method name=\"Get\">\n"
	"      <arg name=\"interface\" type=\"s\" direction=\"in\"/>\n"
	"      <arg name=\"property\" type=\"s\" direction=\"in\"/>\n"
	"      <arg name=\"value\" type=\"v\" direction=\"out\"/>\n"
	"    </method>\n"
	"    <method name=\"Set\">\n"
	"      <arg name=\"interface\" type=\"s\" direction=\"in\"/>\n"
	"      <arg name=\"property\" type=\"s\" direction=\"in\"/>\n"
	"      <arg name=\"value\" type=\"v\" direction=\"in\"/>\n"
	"    </method>\n"
	"    <method name=\"GetAll\">\n"
	"      <arg name=\"interface\" type=\"s\" direction=\"in\"/>\n"
	"      <arg name=\"properties\" type=\"a{sv}\" direction=\"out\"/>\n"
	"    </method>\n"
	"    <signal name=\"PropertiesChanged\">\n"
	"      <arg name=\"interface\" type=\"s\"/>\n"
	"      <arg name=\"changed_properties\" type=\"a{sv}\"/>\n"
	"      <arg name=\"invalidated_properties\" type=\"as\"/>\n"
	"    </signal>\n"
	"  </interface>\n"
	"  <interface name=\"rs.wl.gammarelay\">\n"
	"    <method name=\"ToggleInverted\"/>\n"
	"    <method name=\"UpdateTemperature\">\n"
	"      <arg name=\"delta\" type=\"n\" direction=\"in\"/>\n"
	"    </method>\n"
	"    <method name=\"UpdateGamma\">\n"
	"      <arg name=\"delta\" type=\"d\" direction=\"in\"/>\n"
	"    </method>\n"
	"    <method name=\"UpdateBrightness\">\n"
	"      <arg name=\"delta\" type=\"d\" direction=\"in\"/>\n"
	"    </method>\n"
	"    <property name=\"Inverted\" type=\"b\" access=\"readwrite\">\n"
	"      <annotation name=\"org.freedesktop.DBus.Property.EmitsChangedSignal\" value=\"true\"/>\n"
	"    </property>\n"
	"    <property name=\"Temperature\" type=\"q\" access=\"readwrite\">\n"
	"      <annotation name=\"org.freedesktop.DBus.Property.EmitsChangedSignal\" value=\"true\"/>\n"
	"    </property>\n"
	"    <property name=\"Gamma\" type=\"d\" access=\"readwrite\">\n"
	"      <annotation name=\"org.freedesktop.DBus.Property.EmitsChangedSignal\" value=\"true\"/>\n"
	"    </property>\n"
	"    <property name=\"Brightness\" type=\"d\" access=\"readwrite\">\n"
	"      <annotation name=\"org.freedesktop.DBus.Property.EmitsChangedSignal\" value=\"true\"/>\n"
	"    </property>\n"
	"  </interface>\n"
	"  <node name=\"outputs\"/>\n"
	"</node>\n";

fn ZString introspect_xml_output() =>
	"<!DOCTYPE node PUBLIC \"-//freedesktop//DTD D-BUS Object Introspection 1.0//EN\"\n"
	" \"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd\">\n"
	"<node>\n"
	"  <interface name=\"org.freedesktop.DBus.Introspectable\">\n"
	"    <method name=\"Introspect\">\n"
	"      <arg name=\"data\" type=\"s\" direction=\"out\"/>\n"
	"    </method>\n"
	"  </interface>\n"
	"  <interface name=\"org.freedesktop.DBus.Properties\">\n"
	"    <method name=\"Get\">\n"
	"      <arg name=\"interface\" type=\"s\" direction=\"in\"/>\n"
	"      <arg name=\"property\" type=\"s\" direction=\"in\"/>\n"
	"      <arg name=\"value\" type=\"v\" direction=\"out\"/>\n"
	"    </method>\n"
	"    <method name=\"Set\">\n"
	"      <arg name=\"interface\" type=\"s\" direction=\"in\"/>\n"
	"      <arg name=\"property\" type=\"s\" direction=\"in\"/>\n"
	"      <arg name=\"value\" type=\"v\" direction=\"in\"/>\n"
	"    </method>\n"
	"    <method name=\"GetAll\">\n"
	"      <arg name=\"interface\" type=\"s\" direction=\"in\"/>\n"
	"      <arg name=\"properties\" type=\"a{sv}\" direction=\"out\"/>\n"
	"    </method>\n"
	"    <signal name=\"PropertiesChanged\">\n"
	"      <arg name=\"interface\" type=\"s\"/>\n"
	"      <arg name=\"changed_properties\" type=\"a{sv}\"/>\n"
	"      <arg name=\"invalidated_properties\" type=\"as\"/>\n"
	"    </signal>\n"
	"  </interface>\n"
	"  <interface name=\"rs.wl.gammarelay\">\n"
	"    <method name=\"ToggleInverted\"/>\n"
	"    <method name=\"UpdateTemperature\">\n"
	"      <arg name=\"delta\" type=\"n\" direction=\"in\"/>\n"
	"    </method>\n"
	"    <method name=\"UpdateGamma\">\n"
	"      <arg name=\"delta\" type=\"d\" direction=\"in\"/>\n"
	"    </method>\n"
	"    <method name=\"UpdateBrightness\">\n"
	"      <arg name=\"delta\" type=\"d\" direction=\"in\"/>\n"
	"    </method>\n"
	"    <property name=\"Inverted\" type=\"b\" access=\"readwrite\">\n"
	"      <annotation name=\"org.freedesktop.DBus.Property.EmitsChangedSignal\" value=\"true\"/>\n"
	"    </property>\n"
	"    <property name=\"Temperature\" type=\"q\" access=\"readwrite\">\n"
	"      <annotation name=\"org.freedesktop.DBus.Property.EmitsChangedSignal\" value=\"true\"/>\n"
	"    </property>\n"
	"    <property name=\"Gamma\" type=\"d\" access=\"readwrite\">\n"
	"      <annotation name=\"org.freedesktop.DBus.Property.EmitsChangedSignal\" value=\"true\"/>\n"
	"    </property>\n"
	"    <property name=\"Brightness\" type=\"d\" access=\"readwrite\">\n"
	"      <annotation name=\"org.freedesktop.DBus.Property.EmitsChangedSignal\" value=\"true\"/>\n"
	"    </property>\n"
	"  </interface>\n"
	"</node>\n";

fn ZString introspect_xml_outputs(WaylandState* wl)
{
	DString d;
	d.tinit();
	d.append(
		"<!DOCTYPE node PUBLIC \"-//freedesktop//DTD D-BUS Object Introspection 1.0//EN\"\n"
		" \"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd\">\n"
		"<node>\n"
		"  <interface name=\"org.freedesktop.DBus.Introspectable\">\n"
		"    <method name=\"Introspect\">\n"
		"      <arg name=\"data\" type=\"s\" direction=\"out\"/>\n"
		"    </method>\n"
		"  </interface>\n"
	);
	foreach (out : wl.outputs[:wl.output_count])
	{
		if (out != null && out.has_name)
		{
			d.appendf("  <node name=\"%s\"/>\n", ((ZString)&out.dbus_path[9]).str_view());
		}
	}
	d.append("</node>\n");
	return d.zstr_view();
}

fn void handle_introspect(DbusServer* server, DBusMessage* msg, WaylandState* wl)
{
	ZString path = dbus_message_get_path(msg);
	ZString xml = "";
	if (path == "/")
	{
		xml = introspect_xml_root();
	}
	else if (path == "/outputs")
	{
		xml = introspect_xml_outputs(wl);
	}
	else
	{
		xml = introspect_xml_output();
	}

	DBusMessage* reply = dbus_message_new_method_return(msg);
	if (reply == null)
	{
		return;
	}
	defer dbus_message_unref(reply);

	DBusMessageIter iter;
	dbus_message_iter_init_append(reply, &iter);
	dbus_message_iter_append_basic(&iter, STRING, &xml);

	dbus_connection_send(server.conn, reply, null);
}

fn void handle_prop_get(DbusServer* server, DBusMessage* msg, WaylandState* wl)
{
	DBusMessageIter iter;
	if (!dbus_message_iter_init(msg, &iter))
	{
		return;
	}

	ZString iface;
	dbus_message_iter_get_basic(&iter, &iface);
	dbus_message_iter_next(&iter);

	ZString prop;
	dbus_message_iter_get_basic(&iter, &prop);

	if (iface != DBUS_INTERFACE)
	{
		DBusMessage* err = dbus_message_new_error(msg, "org.freedesktop.DBus.Error.UnknownInterface", "Unknown interface");
		if (err != null)
		{
			dbus_connection_send(server.conn, err, null);
			dbus_message_unref(err);
		}
		return;
	}

	ZString path = dbus_message_get_path(msg);
	Color c;
	if (path == "/")
	{
		c = wayland_get_color(wl);
	}
	else
	{
		Output* out = wayland_find_output_by_path(wl, path);
		if (out == null)
		{
			DBusMessage* err = dbus_message_new_error(msg, "org.freedesktop.DBus.Error.UnknownObject", "Unknown object");
			if (err != null)
			{
				dbus_connection_send(server.conn, err, null);
				dbus_message_unref(err);
			}
			return;
		}
		c = out.color;
	}

	DBusMessage* reply = dbus_message_new_method_return(msg);
	if (reply == null)
	{
		return;
	}
	defer dbus_message_unref(reply);

	DBusMessageIter r_iter;
	dbus_message_iter_init_append(reply, &r_iter);

	DBusMessageIter variant_iter;
	switch (prop.str_view())
	{
		case "Temperature":
			dbus_message_iter_open_container(&r_iter, VARIANT, "q", &variant_iter);
			ushort val = c.temp;
			dbus_message_iter_append_basic(&variant_iter, UINT16, &val);
			dbus_message_iter_close_container(&r_iter, &variant_iter);
		case "Gamma":
			dbus_message_iter_open_container(&r_iter, VARIANT, "d", &variant_iter);
			double val = c.gamma;
			dbus_message_iter_append_basic(&variant_iter, DOUBLE, &val);
			dbus_message_iter_close_container(&r_iter, &variant_iter);
		case "Brightness":
			dbus_message_iter_open_container(&r_iter, VARIANT, "d", &variant_iter);
			double val = c.brightness;
			dbus_message_iter_append_basic(&variant_iter, DOUBLE, &val);
			dbus_message_iter_close_container(&r_iter, &variant_iter);
		case "Inverted":
			dbus_message_iter_open_container(&r_iter, VARIANT, "b", &variant_iter);
			bool val = c.inverted;
			dbus_message_iter_append_basic(&variant_iter, BOOLEAN, &val);
			dbus_message_iter_close_container(&r_iter, &variant_iter);
		default:
			DBusMessage* err = dbus_message_new_error(msg, "org.freedesktop.DBus.Error.UnknownProperty", "Unknown property");
			if (err != null)
			{
				dbus_connection_send(server.conn, err, null);
				dbus_message_unref(err);
			}
			return;
	}

	dbus_connection_send(server.conn, reply, null);
}

fn void handle_prop_set(DbusServer* server, DBusMessage* msg, WaylandState* wl)
{
	DBusMessageIter iter;
	if (!dbus_message_iter_init(msg, &iter))
	{
		return;
	}

	ZString iface;
	dbus_message_iter_get_basic(&iter, &iface);
	dbus_message_iter_next(&iter);

	ZString prop;
	dbus_message_iter_get_basic(&iter, &prop);
	dbus_message_iter_next(&iter);

	DBusMessageIter variant_iter;
	dbus_message_iter_recurse(&iter, &variant_iter);

	ZString path = dbus_message_get_path(msg);
	bool is_root = path == "/";
	Output* target = is_root ? null : wayland_find_output_by_path(wl, path);

	if (!is_root && target == null)
	{
		DBusMessage* err = dbus_message_new_error(msg, "org.freedesktop.DBus.Error.UnknownObject", "Unknown object");
		if (err != null)
		{
			dbus_connection_send(server.conn, err, null);
			dbus_message_unref(err);
		}
		return;
	}

	Color old_global = wayland_get_color(wl);

switch (prop.str_view())
	{
		case "Temperature":
			ushort val;
			dbus_message_iter_get_basic(&variant_iter, &val);
			if (is_root)
			{
				wayland_set_temperature(wl, val);
				ushort cur_val = wayland_get_color(wl).temp;
				dbus_server_signal_change(server, "/", "Temperature", UINT16, "q", &cur_val);
				dbus_server_signal_outputs(server, wl, "Temperature", UINT16, "q", &cur_val);
			}
			else if (target.color.set_temp(val))
			{
				target.color_changed = true;
				ushort cur_val = target.color.temp;
				dbus_server_signal_change(server, path, "Temperature", UINT16, "q", &cur_val);
				ushort cur_g = wayland_get_color(wl).temp;
				if (cur_g != old_global.temp)
				{
					dbus_server_signal_change(server, "/", "Temperature", UINT16, "q", &cur_g);
				}
			}
		case "Gamma":
			double val;
			dbus_message_iter_get_basic(&variant_iter, &val);
			if (is_root)
			{
				wayland_set_gamma(wl, val);
				double cur_val = wayland_get_color(wl).gamma;
				dbus_server_signal_change(server, "/", "Gamma", DOUBLE, "d", &cur_val);
				dbus_server_signal_outputs(server, wl, "Gamma", DOUBLE, "d", &cur_val);
			}
			else if (target.color.set_gamma(val))
			{
				target.color_changed = true;
				double cur_val = target.color.gamma;
				dbus_server_signal_change(server, path, "Gamma", DOUBLE, "d", &cur_val);
				double cur_g = wayland_get_color(wl).gamma;
				if (cur_g != old_global.gamma)
				{
					dbus_server_signal_change(server, "/", "Gamma", DOUBLE, "d", &cur_g);
				}
			}
		case "Brightness":
			double val;
			dbus_message_iter_get_basic(&variant_iter, &val);
			if (is_root)
			{
				wayland_set_brightness(wl, val);
				double cur_val = wayland_get_color(wl).brightness;
				dbus_server_signal_change(server, "/", "Brightness", DOUBLE, "d", &cur_val);
				dbus_server_signal_outputs(server, wl, "Brightness", DOUBLE, "d", &cur_val);
			}
			else if (target.color.set_brightness(val))
			{
				target.color_changed = true;
				double cur_val = target.color.brightness;
				dbus_server_signal_change(server, path, "Brightness", DOUBLE, "d", &cur_val);
				double cur_b = wayland_get_color(wl).brightness;
				if (cur_b != old_global.brightness)
				{
					dbus_server_signal_change(server, "/", "Brightness", DOUBLE, "d", &cur_b);
				}
			}
		case "Inverted":
			int b_int;
			dbus_message_iter_get_basic(&variant_iter, &b_int);
			bool val = (b_int != 0);
			int vi = (int)val;
			if (is_root)
			{
				wayland_set_inverted(wl, val);
				dbus_server_signal_change(server, "/", "Inverted", BOOLEAN, "b", &vi);
				dbus_server_signal_outputs(server, wl, "Inverted", BOOLEAN, "b", &vi);
			}
			else
			{
				target.color.inverted = val;
				target.color_changed = true;
				dbus_server_signal_change(server, path, "Inverted", BOOLEAN, "b", &vi);
				bool cur_inv = wayland_get_color(wl).inverted;
				if (cur_inv != old_global.inverted)
				{
					int gi = (int)cur_inv;
					dbus_server_signal_change(server, "/", "Inverted", BOOLEAN, "b", &gi);
				}
			}
	}

	wayland_apply_pending(wl);

	DBusMessage* reply = dbus_message_new_method_return(msg);
	if (reply != null)
	{
		dbus_connection_send(server.conn, reply, null);
		dbus_message_unref(reply);
	}
}

fn void handle_prop_get_all(DbusServer* server, DBusMessage* msg, WaylandState* wl)
{
	ZString path = dbus_message_get_path(msg);
	Color c;
	if (path == "/")
	{
		c = wayland_get_color(wl);
	}
	else
	{
		Output* out = wayland_find_output_by_path(wl, path);
		if (out == null)
		{
			DBusMessage* err = dbus_message_new_error(msg, "org.freedesktop.DBus.Error.UnknownObject", "Unknown object");
			if (err != null)
			{
				dbus_connection_send(server.conn, err, null);
				dbus_message_unref(err);
			}
			return;
		}
		c = out.color;
	}

	DBusMessage* reply = dbus_message_new_method_return(msg);
	if (reply == null)
	{
		return;
	}
	defer dbus_message_unref(reply);

	DBusMessageIter iter;
	dbus_message_iter_init_append(reply, &iter);

	DBusMessageIter dict;
	dbus_message_iter_open_container(&iter, ARRAY, "{sv}", &dict);

	append_dict_variant(&dict, "Inverted", BOOLEAN, "b", &c.inverted);

	ushort temp = c.temp;
	append_dict_variant(&dict, "Temperature", UINT16, "q", &temp);

	double gamma = c.gamma;
	append_dict_variant(&dict, "Gamma", DOUBLE, "d", &gamma);

	double bright = c.brightness;
	append_dict_variant(&dict, "Brightness", DOUBLE, "d", &bright);

	dbus_message_iter_close_container(&iter, &dict);

	dbus_connection_send(server.conn, reply, null);
}

fn void handle_toggle_inverted(DbusServer* server, DBusMessage* msg, WaylandState* wl)
{
	ZString path = dbus_message_get_path(msg);
	bool is_root = path == "/";

	if (is_root)
	{
		bool new_inv = !wayland_get_color(wl).inverted;
		wayland_set_inverted(wl, new_inv);
		int val = (int)new_inv;
		dbus_server_signal_change(server, "/", "Inverted", BOOLEAN, "b", &val);
		dbus_server_signal_outputs(server, wl, "Inverted", BOOLEAN, "b", &val);
	}
	else
	{
		Output* out = wayland_find_output_by_path(wl, path);
		if (out != null)
		{
			Color old_g = wayland_get_color(wl);
			out.color.inverted = !out.color.inverted;
			out.color_changed = true;
			int val = (int)out.color.inverted;
			dbus_server_signal_change(server, path, "Inverted", BOOLEAN, "b", &val);
			bool cur_g = wayland_get_color(wl).inverted;
			if (cur_g != old_g.inverted)
			{
				int gval = (int)cur_g;
				dbus_server_signal_change(server, "/", "Inverted", BOOLEAN, "b", &gval);
			}
		}
	}

	wayland_apply_pending(wl);

	DBusMessage* reply = dbus_message_new_method_return(msg);
	if (reply != null)
	{
		dbus_connection_send(server.conn, reply, null);
		dbus_message_unref(reply);
	}
}

fn void handle_update_temperature(DbusServer* server, DBusMessage* msg, WaylandState* wl)
{
	DBusMessageIter iter;
	if (!dbus_message_iter_init(msg, &iter))
	{
		return;
	}

	short delta = 0;
	dbus_message_iter_get_basic(&iter, &delta);

	ZString path = dbus_message_get_path(msg);
	bool is_root = path == "/";

	if (is_root)
	{
		if (wayland_update_temperature(wl, delta))
		{
			ushort val = wayland_get_color(wl).temp;
			dbus_server_signal_change(server, "/", "Temperature", UINT16, "q", &val);
			dbus_server_signal_outputs(server, wl, "Temperature", UINT16, "q", &val);
		}
	}
	else
	{
		Output* out = wayland_find_output_by_path(wl, path);
		if (out != null)
		{
			Color old_g = wayland_get_color(wl);
			if (out.color.update_temp(delta))
			{
				out.color_changed = true;
				ushort val = out.color.temp;
				dbus_server_signal_change(server, path, "Temperature", UINT16, "q", &val);
				ushort cur_g = wayland_get_color(wl).temp;
				if (cur_g != old_g.temp)
				{
					dbus_server_signal_change(server, "/", "Temperature", UINT16, "q", &cur_g);
				}
			}
		}
	}

	wayland_apply_pending(wl);

	DBusMessage* reply = dbus_message_new_method_return(msg);
	if (reply != null)
	{
		dbus_connection_send(server.conn, reply, null);
		dbus_message_unref(reply);
	}
}

fn void handle_update_gamma(DbusServer* server, DBusMessage* msg, WaylandState* wl)
{
	DBusMessageIter iter;
	if (!dbus_message_iter_init(msg, &iter))
	{
		return;
	}

	double delta = 0.0;
	dbus_message_iter_get_basic(&iter, &delta);

	ZString path = dbus_message_get_path(msg);
	bool is_root = path == "/";

	if (is_root)
	{
		if (wayland_update_gamma(wl, delta))
		{
			double val = wayland_get_color(wl).gamma;
			dbus_server_signal_change(server, "/", "Gamma", DOUBLE, "d", &val);
			dbus_server_signal_outputs(server, wl, "Gamma", DOUBLE, "d", &val);
		}
	}
	else
	{
		Output* out = wayland_find_output_by_path(wl, path);
		if (out != null)
		{
			Color old_g = wayland_get_color(wl);
			if (out.color.update_gamma(delta))
			{
				out.color_changed = true;
				double val = out.color.gamma;
				dbus_server_signal_change(server, path, "Gamma", DOUBLE, "d", &val);
				double cur_g = wayland_get_color(wl).gamma;
				if (cur_g != old_g.gamma)
				{
					dbus_server_signal_change(server, "/", "Gamma", DOUBLE, "d", &cur_g);
				}
			}
		}
	}

	wayland_apply_pending(wl);

	DBusMessage* reply = dbus_message_new_method_return(msg);
	if (reply != null)
	{
		dbus_connection_send(server.conn, reply, null);
		dbus_message_unref(reply);
	}
}

fn void handle_update_brightness(DbusServer* server, DBusMessage* msg, WaylandState* wl)
{
	DBusMessageIter iter;
	if (!dbus_message_iter_init(msg, &iter))
	{
		return;
	}

	double delta = 0.0;
	dbus_message_iter_get_basic(&iter, &delta);

	ZString path = dbus_message_get_path(msg);
	bool is_root = path == "/";

	if (is_root)
	{
		if (wayland_update_brightness(wl, delta))
		{
			double val = wayland_get_color(wl).brightness;
			dbus_server_signal_change(server, "/", "Brightness", DOUBLE, "d", &val);
			dbus_server_signal_outputs(server, wl, "Brightness", DOUBLE, "d", &val);
		}
	}
	else
	{
		Output* out = wayland_find_output_by_path(wl, path);
		if (out != null)
		{
			Color old_g = wayland_get_color(wl);
			if (out.color.update_brightness(delta))
			{
				out.color_changed = true;
				double val = out.color.brightness;
				dbus_server_signal_change(server, path, "Brightness", DOUBLE, "d", &val);
				double cur_b = wayland_get_color(wl).brightness;
				if (cur_b != old_g.brightness)
				{
					dbus_server_signal_change(server, "/", "Brightness", DOUBLE, "d", &cur_b);
				}
			}
		}
	}

	wayland_apply_pending(wl);

	DBusMessage* reply = dbus_message_new_method_return(msg);
	if (reply != null)
	{
		dbus_connection_send(server.conn, reply, null);
		dbus_message_unref(reply);
	}
}

fn void dbus_server_dispatch_message(DbusServer* server, DBusMessage* msg, WaylandState* wl)
{
	if (dbus_message_get_type(msg) != DBUS_MESSAGE_TYPE_METHOD_CALL)
	{
		return;
	}

	ZString iface = dbus_message_get_interface(msg);
	ZString member = dbus_message_get_member(msg);
	if (member == null)
	{
		return;
	}

	if (member == "Ping")
	{
		DBusMessage* reply = dbus_message_new_method_return(msg);
		if (reply != null)
		{
			dbus_connection_send(server.conn, reply, null);
			dbus_message_unref(reply);
		}
		return;
	}

	if (member == "Introspect")
	{
		handle_introspect(server, msg, wl);
		return;
	}

	if (iface == "org.freedesktop.DBus.Properties")
	{
		switch (member.str_view())
		{
			case "Get":
				handle_prop_get(server, msg, wl);
			case "Set":
				handle_prop_set(server, msg, wl);
			case "GetAll":
				handle_prop_get_all(server, msg, wl);
		}
		return;
	}

	if (iface == DBUS_INTERFACE)
	{
		switch (member.str_view())
		{
			case "ToggleInverted":
				handle_toggle_inverted(server, msg, wl);
			case "UpdateTemperature":
				handle_update_temperature(server, msg, wl);
			case "UpdateGamma":
				handle_update_gamma(server, msg, wl);
			case "UpdateBrightness":
				handle_update_brightness(server, msg, wl);
		}
	}
}

fn void dbus_server_poll(DbusServer* server, WaylandState* wl)
{
	dbus_connection_read_write(server.conn, 0);

	DBusMessage* msg;
	while ((msg = dbus_connection_pop_message(server.conn)) != null)
	{
		dbus_server_dispatch_message(server, msg, wl);
		dbus_message_unref(msg);
	}
	dbus_connection_flush(server.conn);
}

fn bool dbus_client_query_prop_uint16(DBusConnection* conn, ZString prop, ushort* out)
{
	DBusMessage* msg = dbus_message_new_method_call(
		DBUS_SERVICE_NAME,
		"/",
		"org.freedesktop.DBus.Properties",
		"Get"
	);
	if (msg == null)
	{
		return false;
	}
	defer dbus_message_unref(msg);

	DBusMessageIter iter;
	dbus_message_iter_init_append(msg, &iter);
	dbus_message_iter_append_basic(&iter, STRING, &DBUS_INTERFACE);
	dbus_message_iter_append_basic(&iter, STRING, &prop);

	DBusError err;
	dbus_error_init(&err);
	defer dbus_error_free(&err);

	DBusMessage* reply = dbus_connection_send_with_reply_and_block(conn, msg, 1000, &err);
	if (reply == null)
	{
		return false;
	}
	defer dbus_message_unref(reply);

	DBusMessageIter r_iter;
	if (!dbus_message_iter_init(reply, &r_iter))
	{
		return false;
	}
	if (dbus_message_iter_get_arg_type(&r_iter) != VARIANT)
	{
		return false;
	}

	DBusMessageIter variant_iter;
	dbus_message_iter_recurse(&r_iter, &variant_iter);
	dbus_message_iter_get_basic(&variant_iter, out);
	return true;
}

fn bool dbus_client_query_prop_double(DBusConnection* conn, ZString prop, double* out)
{
	DBusMessage* msg = dbus_message_new_method_call(
		DBUS_SERVICE_NAME,
		"/",
		"org.freedesktop.DBus.Properties",
		"Get"
	);
	if (msg == null)
	{
		return false;
	}
	defer dbus_message_unref(msg);

	DBusMessageIter iter;
	dbus_message_iter_init_append(msg, &iter);
	dbus_message_iter_append_basic(&iter, STRING, &DBUS_INTERFACE);
	dbus_message_iter_append_basic(&iter, STRING, &prop);

	DBusError err;
	dbus_error_init(&err);
	defer dbus_error_free(&err);

	DBusMessage* reply = dbus_connection_send_with_reply_and_block(conn, msg, 1000, &err);
	if (reply == null)
	{
		return false;
	}
	defer dbus_message_unref(reply);

	DBusMessageIter r_iter;
	if (!dbus_message_iter_init(reply, &r_iter))
	{
		return false;
	}
	if (dbus_message_iter_get_arg_type(&r_iter) != VARIANT)
	{
		return false;
	}

	DBusMessageIter variant_iter;
	dbus_message_iter_recurse(&r_iter, &variant_iter);
	dbus_message_iter_get_basic(&variant_iter, out);
	return true;
}

fn void dbus_client_print(DbusClient* client)
{
	if (client.initialized &&
		client.temperature == client.prev_temperature &&
		client.gamma == client.prev_gamma &&
		client.brightness == client.prev_brightness)
	{
		return;
	}

	client.prev_temperature = client.temperature;
	client.prev_gamma = client.gamma;
	client.prev_brightness = client.brightness;
	client.initialized = true;

	@pool()
	{
		String out = client.format;
		out = out.treplace("{t}", string::tformat("%d", client.temperature));
		out = out.treplace("{g}", string::tformat("%.2f", client.gamma));
		out = out.treplace("{b}", string::tformat("%.2f", client.brightness));
		out = out.treplace("{bp}", string::tformat("%.0f", client.brightness * 100.0));
		io::printn(out);
	};
}

fn DbusClient*? dbus_client_init(String format, bool server_running)
{
	DBusError err;
	dbus_error_init(&err);
	defer dbus_error_free(&err);

	DBusConnection* conn = dbus_bus_get_private(DBUS_BUS_SESSION, &err);
	if (conn == null)
	{
		return DBUS_INIT_FAILED~;
	}

	ZString match_rule = "type='signal',sender='rs.wl-gammarelay',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'";
	dbus_bus_add_match(conn, match_rule, &err);
	dbus_connection_flush(conn);

	ushort temp = DEFAULT_TEMP;
	double gamma = DEFAULT_GAMMA;
	double brightness = DEFAULT_BRIGHTNESS;

	if (server_running)
	{
		dbus_client_query_prop_uint16(conn, "Temperature", &temp);
		dbus_client_query_prop_double(conn, "Gamma", &gamma);
		dbus_client_query_prop_double(conn, "Brightness", &brightness);
	}

	int fd = -1;
	dbus_connection_get_unix_fd(conn, &fd);

	DbusClient* client = mem::new(DbusClient);
	client.conn = conn;
	client.fd = fd;
	client.format = format;
	client.temperature = temp;
	client.gamma = gamma;
	client.brightness = brightness;

	dbus_client_print(client);
	return client;
}

fn void dbus_client_destroy(DbusClient* client)
{
	if (client == null)
	{
		return;
	}
	if (client.conn != null)
	{
		dbus_connection_close(client.conn);
		dbus_connection_unref(client.conn);
	}
	mem::free(client);
}

fn void dbus_client_poll(DbusClient* client)
{
	dbus_connection_read_write(client.conn, 0);

	DBusMessage* msg;
	while ((msg = dbus_connection_pop_message(client.conn)) != null)
	{
		defer dbus_message_unref(msg);
		if (dbus_message_get_type(msg) != DBUS_MESSAGE_TYPE_SIGNAL)	continue;

		ZString member = dbus_message_get_member(msg);
		if (member != "PropertiesChanged") continue;

		DBusMessageIter iter;
		if (!dbus_message_iter_init(msg, &iter)) continue;

		ZString iface;
		dbus_message_iter_get_basic(&iter, &iface);
		if (iface != DBUS_INTERFACE) continue;

		dbus_message_iter_next(&iter);
		DBusMessageIter dict;
		dbus_message_iter_recurse(&iter, &dict);

		while (dbus_message_iter_get_arg_type(&dict) == DICT_ENTRY)
		{
			DBusMessageIter entry;
			dbus_message_iter_recurse(&dict, &entry);
			ZString name;
			dbus_message_iter_get_basic(&entry, &name);
			dbus_message_iter_next(&entry);

			DBusMessageIter variant_iter;
			dbus_message_iter_recurse(&entry, &variant_iter);

			if (name == "Temperature")
			{
				dbus_message_iter_get_basic(&variant_iter, &client.temperature);
			}
			else if (name == "Gamma")
			{
				dbus_message_iter_get_basic(&variant_iter, &client.gamma);
			}
			else if (name == "Brightness")
			{
				dbus_message_iter_get_basic(&variant_iter, &client.brightness);
			}
			dbus_message_iter_next(&dict);
		}
		dbus_client_print(client);
	}
}

fn int sd_listen_fds(int _dummy @unused) @export("sd_listen_fds") => 0;
fn int sd_is_socket(int _fd @unused, int _family @unused, int _type @unused, int _listening @unused) @export("sd_is_socket") => 0;