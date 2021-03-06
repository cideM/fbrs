+++
title = "Connect to nREPL Running in Docker"
date = "2020-07-17"
[taxonomies]
tags=["docker", "clojure"]
+++

You're creating a Clojure application and you want to make sure that everyone on your team enjoys the same local development setup. So you create a Dockerfile for your app and start the whole thing with Docker Compose.

Except that you can't connect to the nREPL running inside the container. The alias for starting the repl is...

```
:main-opts [
    "-m" 
    "nrepl.cmdline" 
    "--port" 
    "41985"
    "--middleware" 
    "[cider.nrepl/cider-middleware]"
]
```

...and it totally works outside Docker. When trying to `telnet localhost 41985` you just get

> Connection closed by foreign host.

Looks like the requests don't even reach your nREPL server in the first place. 

It took a bit of Googling until I came across [this Stack Overflow answer](https://stackoverflow.com/questions/28015344/docker-listening-in-container-but-not-answering-outside-why) which in turn links to [this other answer](https://stackoverflow.com/questions/54101508/how-do-you-dockerize-a-websocket-server/54102318#54102318). Long story short, the default listening address of nREPL is `localhost`, but requests forwarded from the outside world are sent to the container IP address. Since nREPL is listening on `localhost` but requests come in via something like `172.19.0.2:41985`, nothing works. Adding `--bind 0.0.0.0` to the alias...

```
:main-opts [
    "-m" 
    "nrepl.cmdline" 
    "--bind" 
    "0.0.0.0" 
    "--port" 
    "41985" 
    "--middleware" 
    "[cider.nrepl/cider-middleware]"
]
```

...fixes the problem.

> You probably want to have the service you're running in the container to listen on 0.0.0.0 rather than 127.0.0.1
