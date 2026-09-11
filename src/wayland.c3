module wl_gamma;
import libc, std::os::posix;

excuse WAYLAND_INIT_FAILED, COMPOSITOR_NOT_SUPPORTED;

const sz MAX_OUTPUTS   = 64;
const uint MFD_CLOEXEC = 0x0001;

struct WlDisplay { void* _opaque; }
struct WlRegistry { void* _opaque; }
struct WlOutput { void* _opaque; }
struct ZwlrGammaControlManagerV1 { void* _opaque; }
struct ZwlrGammaControlV1 { void* _opaque; }
struct WlProxy { void* _opaque; }

struct WlMessage
{
	char* name;
	char* signature;
	WlInterface** types;
}

struct WlInterface
{
	char* name;
	int version;
	int method_count;
	WlMessage* methods;
	int event_count;
	WlMessage* events;
}

extern WlInterface wl_registry_interface;
extern WlInterface wl_output_interface;

WlInterface*[2] zwlr_gamma_control_manager_types = {
	&zwlr_gamma_control_v1_interface,
	&wl_output_interface
};

WlMessage[2] zwlr_gamma_control_manager_methods = {
	{ "get_gamma_control", "no", (WlInterface**)&zwlr_gamma_control_manager_types },
	{ "destroy", "", null }
};

WlInterface zwlr_gamma_control_manager_v1_interface = {
	"zwlr_gamma_control_manager_v1",
	1,
	2,
	(WlMessage*)&zwlr_gamma_control_manager_methods,
	0,
	null
};

WlMessage[2] zwlr_gamma_control_methods = {
	{ "set_gamma", "h", null },
	{ "destroy", "", null }
};

WlMessage[2] zwlr_gamma_control_events = {
	{ "gamma_size", "u", null },
	{ "failed", "", null }
};

WlInterface zwlr_gamma_control_v1_interface = {
	"zwlr_gamma_control_v1",
	1,
	2,
	(WlMessage*)&zwlr_gamma_control_methods,
	2,
	(WlMessage*)&zwlr_gamma_control_events
};

alias WlRegistryGlobalFn       = fn void(void* data, WlRegistry* registry, uint name, ZString iface, uint version);
alias WlRegistryGlobalRemoveFn = fn void(void* data, WlRegistry* registry, uint name);

struct WlRegistryListener
{
	WlRegistryGlobalFn global;
	WlRegistryGlobalRemoveFn global_remove;
}

alias WlOutputGeometryFn    = fn void(void* data, WlOutput* output, int x, int y, int pw, int ph, int subpixel, ZString make, ZString model, int transform);
alias WlOutputModeFn        = fn void(void* data, WlOutput* output, uint flags, int width, int height, int refresh);
alias WlOutputDoneFn        = fn void(void* data, WlOutput* output);
alias WlOutputScaleFn       = fn void(void* data, WlOutput* output, int factor);
alias WlOutputNameFn        = fn void(void* data, WlOutput* output, ZString name);
alias WlOutputDescriptionFn = fn void(void* data, WlOutput* output, ZString description);

struct WlOutputListener
{
	WlOutputGeometryFn geometry;
	WlOutputModeFn mode;
	WlOutputDoneFn done;
	WlOutputScaleFn scale;
	WlOutputNameFn name;
	WlOutputDescriptionFn description;
}

alias ZwlrGammaControlGammaSizeFn = fn void(void* data, ZwlrGammaControlV1* control, uint size);
alias ZwlrGammaControlFailedFn    = fn void(void* data, ZwlrGammaControlV1* control);

struct ZwlrGammaControlV1Listener
{
	ZwlrGammaControlGammaSizeFn gamma_size;
	ZwlrGammaControlFailedFn failed;
}

extern fn WlDisplay* wl_display_connect(char* name);
extern fn void wl_display_disconnect(WlDisplay* display);
extern fn int wl_display_get_fd(WlDisplay* display);
extern fn int wl_display_dispatch(WlDisplay* display);
extern fn int wl_display_dispatch_pending(WlDisplay* display);
extern fn int wl_display_flush(WlDisplay* display);
extern fn int wl_display_roundtrip(WlDisplay* display);

extern fn WlProxy* wl_proxy_marshal_flags(WlProxy* proxy, uint opcode, WlInterface* iface, uint version, uint flags, ...);
extern fn uint wl_proxy_get_version(WlProxy* proxy);
extern fn void wl_proxy_destroy(WlProxy* proxy);
extern fn int wl_proxy_add_listener(WlProxy* proxy, void** implementation, void* data);

extern fn int memfd_create(char* name, uint flags);
extern fn int ftruncate(int fd, Off_t length);

struct Output
{
	uint reg_name;
	WlOutput* wl_output;
	ZwlrGammaControlV1* gamma_control;
	char[64] name;
	char[80] dbus_path;
	Color color;
	sz ramp_size;
	bool color_changed;
	bool failed;
	bool has_name;
}

struct WaylandState
{
	WlDisplay* display;
	WlRegistry* registry;
	ZwlrGammaControlManagerV1* gamma_manager;
	Output*[MAX_OUTPUTS] outputs;
	sz output_count;
	int fd;
}

WlRegistryListener g_registry_listener = {
	.global = &handle_registry_global,
	.global_remove = &handle_registry_global_remove
};

WlOutputListener g_output_listener = {
	.geometry = &handle_output_geometry,
	.mode = &handle_output_mode,
	.done = &handle_output_done,
	.scale = &handle_output_scale,
	.name = &handle_output_name,
	.description = &handle_output_description
};

ZwlrGammaControlV1Listener g_gamma_listener = {
	.gamma_size = &handle_gamma_size,
	.failed = &handle_gamma_failed
};

fn void handle_output_geometry(void* data, WlOutput* o, int x, int y, int pw, int ph, int sp, ZString mk, ZString md, int tf) {}
fn void handle_output_mode(void* data, WlOutput* o, uint fl, int w, int h, int r) {}
fn void handle_output_done(void* data, WlOutput* o) {}
fn void handle_output_scale(void* data, WlOutput* o, int f) {}
fn void handle_output_description(void* data, WlOutput* o, ZString desc) {}

fn void handle_output_name(void* data, WlOutput* o, ZString name)
{
	Output* output = (Output*)data;
	if (output == null || name == null)
	{
		return;
	}

	String sname = name.str_view();
	sz len = sname.len < 63 ? sname.len : 63;

	output.name[:len] = sname[:len];
	output.name[len] = '\0';

	String prefix = "/outputs/";
	output.dbus_path[:prefix.len] = prefix[..];

	foreach (idx, c : sname[:len])
	{
		output.dbus_path[prefix.len + idx] = (c == '-') ? '_' : c;
	}
	output.dbus_path[prefix.len + len] = '\0';
	output.has_name = true;
}

fn void output_bind_gamma(Output* output, ZwlrGammaControlManagerV1* mgr)
{
	if (output.gamma_control != null || mgr == null)
	{
		return;
	}

	output.gamma_control = (ZwlrGammaControlV1*)wl_proxy_marshal_flags(
		(WlProxy*)mgr,
		0,
		&zwlr_gamma_control_v1_interface,
		1,
		0,
		null,
		output.wl_output
	);
	wl_proxy_add_listener((WlProxy*)output.gamma_control, (void**)&g_gamma_listener, output);
}

fn void handle_gamma_size(void* data, ZwlrGammaControlV1* ctrl, uint size)
{
	Output* output = (Output*)data;
	if (output == null)
	{
		return;
	}
	output.ramp_size = (sz)size;
	output.color_changed = true;
	output_apply_gamma(output);
}

fn void handle_gamma_failed(void* data, ZwlrGammaControlV1* ctrl)
{
	Output* output = (Output*)data;
	if (output == null)
	{
		return;
	}
	output.failed = true;
	if (output.gamma_control != null)
	{
		wl_proxy_destroy((WlProxy*)output.gamma_control);
		output.gamma_control = null;
	}
}

fn void handle_registry_global(void* data, WlRegistry* reg, uint name, ZString iface, uint version)
{
	WaylandState* state = (WaylandState*)data;

	if (iface == "zwlr_gamma_control_manager_v1")
	{
		state.gamma_manager = (ZwlrGammaControlManagerV1*)wl_proxy_marshal_flags(
			(WlProxy*)reg,
			0,
			&zwlr_gamma_control_manager_v1_interface,
			1,
			0,
			name,
			zwlr_gamma_control_manager_v1_interface.name,
			1,
			null
		);
		foreach (out : state.outputs[:state.output_count])
		{
			output_bind_gamma(out, state.gamma_manager);
		}
		return;
	}

	if (iface == "wl_output")
	{
		if (state.output_count >= MAX_OUTPUTS)
		{
			return;
		}

		uint bind_ver = version < 4 ? version : 4;
		WlOutput* wlr_out = (WlOutput*)wl_proxy_marshal_flags(
			(WlProxy*)reg,
			0,
			&wl_output_interface,
			bind_ver,
			0,
			name,
			wl_output_interface.name,
			bind_ver,
			null
		);

		Output* out = mem::new(Output);
		out.reg_name = name;
		out.wl_output = wlr_out;
		out.color = color_default();
		out.color_changed = true;

		wl_proxy_add_listener((WlProxy*)wlr_out, (void**)&g_output_listener, out);
		state.outputs[state.output_count++] = out;

		if (state.gamma_manager != null)
		{
			output_bind_gamma(out, state.gamma_manager);
		}
	}
}

fn void handle_registry_global_remove(void* data, WlRegistry* reg, uint name)
{
	WaylandState* state = (WaylandState*)data;
	for (sz i = 0; i < state.output_count; i++)
	{
		Output* out = state.outputs[i];
		if (out == null || out.reg_name != name)
		{
			continue;
		}
		if (out.gamma_control != null)
		{
			wl_proxy_destroy((WlProxy*)out.gamma_control);
		}
		if (out.wl_output != null)
		{
			wl_proxy_destroy((WlProxy*)out.wl_output);
		}
		mem::free(out);
		state.outputs[i] = state.outputs[--state.output_count];
		state.outputs[state.output_count] = null;
		break;
	}
}

fn WaylandState*? wayland_init()
{
	WlDisplay* display = wl_display_connect(null);
	if (display == null)
	{
		return WAYLAND_INIT_FAILED~;
	}

	WaylandState* state = mem::new(WaylandState);
	state.display = display;
	state.fd = wl_display_get_fd(display);

	state.registry = (WlRegistry*)wl_proxy_marshal_flags(
		(WlProxy*)display,
		1,
		&wl_registry_interface,
		wl_proxy_get_version((WlProxy*)display),
		0,
		null
	);
	wl_proxy_add_listener((WlProxy*)state.registry, (void**)&g_registry_listener, state);

	wl_display_roundtrip(display);
	wl_display_roundtrip(display);

	if (state.gamma_manager == null)
	{
		wayland_destroy(state);
		return COMPOSITOR_NOT_SUPPORTED~;
	}
	return state;
}

fn void wayland_destroy(WaylandState* state)
{
	if (state == null)
	{
		return;
	}
	for (sz i = 0; i < state.output_count; i++)
	{
		Output* out = state.outputs[i];
		if (out == null)
		{
			continue;
		}
		if (out.gamma_control != null)
		{
			wl_proxy_destroy((WlProxy*)out.gamma_control);
		}
		if (out.wl_output != null)
		{
			wl_proxy_destroy((WlProxy*)out.wl_output);
		}
		mem::free(out);
	}
	if (state.gamma_manager != null)
	{
		wl_proxy_destroy((WlProxy*)state.gamma_manager);
	}
	if (state.registry != null)
	{
		wl_proxy_destroy((WlProxy*)state.registry);
	}
	if (state.display != null)
	{
		wl_display_disconnect(state.display);
	}
	mem::free(state);
}

fn void output_apply_gamma(Output* output)
{
	if (output.ramp_size == 0 || output.failed || output.gamma_control == null)
	{
		return;
	}

	usz total_bytes = (usz)(output.ramp_size * ushort::size * 3);
	int fd = memfd_create("ramp-buffer", MFD_CLOEXEC);
	if (fd < 0)
	{
		return;
	}

	if (ftruncate(fd, (Off_t)total_bytes) != 0)
	{
		libc::close(fd);
		return;
	}

	void* ptr = posix::mmap(null, total_bytes, posix::PROT_READ | posix::PROT_WRITE, posix::MAP_SHARED, fd, 0);
	if (ptr == null || ptr == posix::MAP_FAILED)
	{
		libc::close(fd);
		return;
	}

	ushort* r = (ushort*)ptr;
	ushort* g = r + output.ramp_size;
	ushort* b = g + output.ramp_size;

	colorramp_fill(r, g, b, output.ramp_size, output.color);
	posix::munmap(ptr, total_bytes);

	wl_proxy_marshal_flags(
		(WlProxy*)output.gamma_control,
		0,
		null,
		wl_proxy_get_version((WlProxy*)output.gamma_control),
		0,
		fd
	);
	libc::close(fd);
	output.color_changed = false;
}

fn void wayland_apply_pending(WaylandState* state)
{
	foreach (out : state.outputs[:state.output_count])
	{
		if (out != null && out.color_changed)
		{
			output_apply_gamma(out);
		}
	}
	wl_display_flush(state.display);
}

fn Color wayland_get_color(WaylandState* state)
{
	if (state.output_count == 0)
	{
		return color_default();
	}

	ulong temp_sum = 0;
	double gamma_sum = 0.0;
	double brightness_sum = 0.0;
	bool all_inverted = true;

	foreach (out : state.outputs[:state.output_count])
	{
		temp_sum += (ulong)out.color.temp;
		gamma_sum += out.color.gamma;
		brightness_sum += out.color.brightness;
		if (!out.color.inverted)
		{
			all_inverted = false;
		}
	}

	double count = (double)state.output_count;
	return {
		.temp = (ushort)(temp_sum / (ulong)state.output_count),
		.gamma = gamma_sum / count,
		.brightness = brightness_sum / count,
		.inverted = all_inverted
	};
}

fn Output* wayland_find_output_by_path(WaylandState* state, ZString path)
{
	foreach (out : state.outputs[:state.output_count])
	{
		if (out != null && (ZString)&out.dbus_path == path)
		{
			return out;
		}
	}
	return null;
}

fn void wayland_set_inverted(WaylandState* state, bool val)
{
	foreach (out : state.outputs[:state.output_count])
	{
		out.color.inverted = val;
		out.color_changed = true;
	}
}

fn bool wayland_update_temperature(WaylandState* state, short delta)
{
	bool updated = false;
	foreach (out : state.outputs[:state.output_count])
	{
		if (out.color.update_temp(delta))
		{
			out.color_changed = true;
			updated = true;
		}
	}
	return updated;
}

fn void wayland_set_temperature(WaylandState* state, ushort temp)
{
	foreach (out : state.outputs[:state.output_count])
	{
		if (out.color.set_temp(temp)) out.color_changed = true;
	}
}

fn bool wayland_update_gamma(WaylandState* state, double delta)
{
	bool updated = false;
	foreach (out : state.outputs[:state.output_count])
	{
		if (out.color.update_gamma(delta))
		{
			out.color_changed = true;
			updated = true;
		}
	}
	return updated;
}

fn void wayland_set_gamma(WaylandState* state, double val)
{
	foreach (out : state.outputs[:state.output_count])
	{
		if (out.color.set_gamma(val))
		{
			out.color_changed = true;
		}
	}
}

fn bool wayland_update_brightness(WaylandState* state, double delta)
{
	bool updated = false;
	foreach (out : state.outputs[:state.output_count])
	{
		if (out.color.update_brightness(delta))
		{
			out.color_changed = true;
			updated = true;
		}
	}
	return updated;
}

fn void wayland_set_brightness(WaylandState* state, double val)
{
	foreach (out : state.outputs[:state.output_count])
	{
		if (out.color.set_brightness(val))
		{
			out.color_changed = true;
		}
	}
}