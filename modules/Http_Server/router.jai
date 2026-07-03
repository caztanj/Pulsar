init :: (router: *Http_Router) {
    allocator := Allocator.{ proc = flat_pool_allocator_proc, data = *router.flat_pool };
    push_allocator(allocator);

    remember_allocators(router);
    remember_allocators(*router.get);
    remember_allocators(*router.head);
    remember_allocators(*router.post);
    remember_allocators(*router.put);
    remember_allocators(*router.delete);
    remember_allocators(*router.connect);
    remember_allocators(*router.options);
    remember_allocators(*router.trace);
    remember_allocators(*router.patch);
    remember_allocators(*router.web_socket);
}

http_router_handle_request :: (router: *Http_Router, request: Http_Request) -> handled: bool, Http_Response {
    routes: [] Http_Route;

    if #complete request.method == {
        case .GET;     routes = router.get;
        case .HEAD;    routes = router.head;
        case .POST;    routes = router.post;
        case .PUT;     routes = router.put;
        case .DELETE;  routes = router.delete;
        case .CONNECT; routes = router.connect;
        case .OPTIONS; routes = router.options;
        case .TRACE;   routes = router.trace;
        case .PATCH;   routes = router.patch;
    }

    glob_route: *Http_Route;
    best_glob_match_count := -1;

    for * routes {
        if it.path == request.uri {
            response := it.handler(request);
            return true, response;
        }

        if ends_with(it.path, "*") {
            prefix_length := it.path.count - 1;
            if prefix_length > best_glob_match_count && request.uri.count >= prefix_length {
                path := slice(it.path, 0, prefix_length);
                if starts_with(request.uri, path) {
                    glob_route = it;
                    best_glob_match_count = prefix_length;
                }
            }
        }
    }

    if glob_route != null {
        response := glob_route.handler(request);
        return true, response;
    }

    return false, .{};
}

fini :: (router: *Http_Router) {
    fini(*router.flat_pool);
}

get     :: #bake_arguments add_route(method = .GET);
head    :: #bake_arguments add_route(method = .HEAD);
post    :: #bake_arguments add_route(method = .POST);
put     :: #bake_arguments add_route(method = .PUT);
delete  :: #bake_arguments add_route(method = .DELETE);
connect :: #bake_arguments add_route(method = .CONNECT);
options :: #bake_arguments add_route(method = .OPTIONS);
trace   :: #bake_arguments add_route(method = .TRACE);
patch   :: #bake_arguments add_route(method = .PATCH);

web_socket :: (router: *Http_Router, path: string, handler: Web_Socket_Upgrade_Handler) {
    array_add(*router.web_socket, .{ path = path, handler = handler });
}

http_router_handle_web_socket :: (server: *Http_Server, router: *Http_Router, request: Http_Request) -> handled: bool {
    if request.method != .GET return false;

    _, upgrade := get_header(request.headers, "Upgrade");
    if !equal_nocase(upgrade, "websocket") return false;

    handle :: (route: *Http_Web_Socket_Route) #expand {
        ok := route.handler(server, request);
        if !ok {
            response := bad_request(request);
            send_response(server, response);
        }

        `return true;
    }

    glob_route: *Http_Web_Socket_Route;
    best_glob_match_count := -1;

    for * router.web_socket {
        if it.path == request.uri handle(it);

        if ends_with(it.path, "*") {
            prefix_length := it.path.count - 1;
            if prefix_length > best_glob_match_count && request.uri.count >= prefix_length {
                path := slice(it.path, 0, prefix_length);
                if starts_with(request.uri, path) {
                    glob_route = it;
                    best_glob_match_count = prefix_length;
                }
            }
        }
    }

    if glob_route != null handle(glob_route);

    return false;
}

add_route :: (router: *Http_Router, method: Http_Method, path: string, handler: Http_Route_Handler) {
    if #complete method == {
        case .GET;     array_add(*router.get,     .{ path = path, handler = handler });
        case .HEAD;    array_add(*router.head,    .{ path = path, handler = handler });
        case .POST;    array_add(*router.post,    .{ path = path, handler = handler });
        case .PUT;     array_add(*router.put,     .{ path = path, handler = handler });
        case .DELETE;  array_add(*router.delete,  .{ path = path, handler = handler });
        case .CONNECT; array_add(*router.connect, .{ path = path, handler = handler });
        case .OPTIONS; array_add(*router.options, .{ path = path, handler = handler });
        case .TRACE;   array_add(*router.trace,   .{ path = path, handler = handler });
        case .PATCH;   array_add(*router.patch,   .{ path = path, handler = handler });
    }
}

Http_Router :: struct {
    get:     [..] Http_Route;
    head:    [..] Http_Route;
    post:    [..] Http_Route;
    put:     [..] Http_Route;
    delete:  [..] Http_Route;
    connect: [..] Http_Route;
    options: [..] Http_Route;
    trace:   [..] Http_Route;
    patch:   [..] Http_Route;

    web_socket: [..] Http_Web_Socket_Route;

    allocator: Allocator;
    flat_pool: Flat_Pool;
}

Http_Route_Handler         :: #type (request: Http_Request) -> Http_Response;
Web_Socket_Upgrade_Handler :: #type (server: *Http_Server, request: Http_Request) -> accepted: bool;

#scope_module

Http_Route :: struct {
    path:    string;
    handler: Http_Route_Handler;
}

Http_Web_Socket_Route :: struct {
    path:    string;
    handler: Web_Socket_Upgrade_Handler;
}