module wl_gamma;
import libc, std::io, std::net::os;

bool g_running = true;

fn void handle_sig(CInt sig)
{
	g_running = false;
}

fn void print_usage()
{
	io::printn("Usage: wl-gamma [COMMAND]");
	io::printn("Commands:");
	io::printn("  run             Run the compositor gamma relay server (default)");
	io::printn("  watch <format>  Watch properties and print formatted output ({t}, {g}, {b}, {bp})");
	io::printn("  -h, --help      Show this help message");
}

fn void event_loop(WaylandState* wl, DbusServer* server, DbusClient* client)
{
	os::Posix_pollfd[3] pfds;

	while (g_running)
	{
		if (wl != null)
		{
			while (wl_display_dispatch_pending(wl.display) > 0)
			{
			}
			wl_display_flush(wl.display);
		}

		CUInt nfds = 0;
		int wl_idx  = -1;
		int srv_idx = -1;
		int cli_idx = -1;

		if (wl != null)
		{
			wl_idx = (int)nfds;
			pfds[nfds++] = { .fd = wl.fd, .events = os::POLLIN };
		}
		if (server != null)
		{
			srv_idx = (int)nfds;
			pfds[nfds++] = { .fd = server.fd, .events = os::POLLIN };
		}
		if (client != null)
		{
			cli_idx = (int)nfds;
			pfds[nfds++] = { .fd = client.fd, .events = os::POLLIN };
		}

		if (os::poll(&pfds[0], nfds, -1) < 0)
		{
			if (!g_running)
			{
				break;
			}
			continue;
		}

		if (wl_idx >= 0 && (pfds[wl_idx].revents & os::POLLIN) != 0)
		{
			wl_display_dispatch(wl.display);
		}
		if (srv_idx >= 0 && (pfds[srv_idx].revents & os::POLLIN) != 0)
		{
			dbus_server_poll(server, wl);
		}
		if (cli_idx >= 0 && (pfds[cli_idx].revents & os::POLLIN) != 0)
		{
			dbus_client_poll(client);
		}
	}
}

fn int run_server()
{
	DbusServer*? server = dbus_server_init();
	if (catch err = server)
	{
		if (err == SERVER_ALREADY_RUNNING)
		{
			io::eprintn("wl-gamma is already running");
			return 1;
		}
		io::eprintn("Failed to connect to D-Bus session bus");
		return 1;
	}
	defer dbus_server_destroy(server);

	WaylandState*? wl = wayland_init();
	if (catch wl)
	{
		io::eprintn("Your Wayland compositor is not supported or connection failed");
		return 1;
	}
	defer wayland_destroy(wl);

	event_loop(wl, server, null);
	return 0;
}

fn int run_watch(String format)
{
	DbusServer*? server = dbus_server_init();
	if (catch err = server)
	{
		if (err != SERVER_ALREADY_RUNNING)
		{
			io::eprintn("Failed to connect to D-Bus session bus");
			return 1;
		}

		DbusClient*? client = dbus_client_init(format, true);
		if (catch client)
		{
			io::eprintn("Failed to connect to D-Bus session bus");
			return 1;
		}
		defer dbus_client_destroy(client);

		event_loop(null, null, client);
		return 0;
	}
	defer dbus_server_destroy(server);

	WaylandState*? wl = wayland_init();
	if (catch wl)
	{
		io::eprintn("Your Wayland compositor is not supported or connection failed");
		return 1;
	}
	defer wayland_destroy(wl);

	DbusClient*? client = dbus_client_init(format, false);
	if (catch client)
	{
		io::eprintn("Failed to initialize D-Bus client");
		return 1;
	}
	defer dbus_client_destroy(client);

	event_loop(wl, server, client);
	return 0;
}

fn int main(String[] args)
{
	libc::signal(libc::SIGINT, &handle_sig);
	libc::signal(libc::SIGTERM, &handle_sig);

	if (args.len <= 1)
	{
		return run_server();
	}

	switch (args[1])
	{
		case "-h":
		case "--help":
		case "help":
			print_usage();
			return 0;
		case "run":
			return run_server();
		case "watch":
			if (args.len < 3)
			{
				io::eprintn("Error: watch requires a format string");
				print_usage();
				return 1;
			}
			return run_watch(args[2]);
		default:
			io::eprintfn("Unknown command: %s", args[1]);
			print_usage();
			return 1;
	}
}