#Use only via ZMQSer package

global _responder   # since eval works in global scope, can't use a closure for zmqquit

function respond_error(responder::ZMQSocket, thiserr::Exception)
    if isa(thiserr, ZMQStateError)
        # ZMQ state is corrupted, so we can't reliably report to the
        # client. Report this error on the server.
        throw(thiserr)
    else
        println("Reporting this error to the client: ", thiserr)
        # Report the error to the client
        zmq_serialize(responder, thiserr)
    end
end

function parse_eval(scope, str::ASCIIString)
    p = parse(str)
    eval(scope, p)
end

function zmqquit()
    println("About to quit")
    zmq_serialize(_responder, nothing)
    exit()
end

function run_server(scope, endpoint::ASCIIString)
    global _responder
    zctx = ZMQContext()
    _responder = ZMQSocket(zctx, ZMQ_REP)
    bind(_responder, endpoint)

    while true
        # Get the next command
        local ex
        local ismulti
        try
            ex = zmq_deserialize(_responder)
        catch thiserr
            respond_error(_responder, thiserr)
            continue
        end
        # Execute the command
        local ret
        try
            ret = eval(scope,ex)
        catch thiserr
            respond_error(_responder, thiserr)
            continue
        end
        # Send the results back
        try
            zmq_serialize(_responder, ret)
        catch thiserr
            respond_error(_responder, thiserr)
        end
    end
end
run_server() = run_server("tcp://*:5555")
run_server(endpoint::ASCIIString) = run_server(current_module(), endpoint)

current_module() = ccall(:jl_get_current_module, Any, ())::Module
