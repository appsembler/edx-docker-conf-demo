This repo was created for the "Getting Started with Open edX development" workshop at the Open edX 2018 Conference in Montreal.

It provides a complete developer environment for working with the Open edX software platform, including a code editor (Orion) and terminal/shell (Gotty).
All of Open edX's dependencies (MySQL, Mongo, RabbitMQ) are running in a single Docker container. 

While this is not a recommended way to do it in production, for training and evaluation purposes, the simplicity of having everything in one container, outweighed the complexity of a multi-container deployment.

# Build the image

To build and run the Docker image, you must first have Docker installed on your computer.

```
$ git clone https://github.com/appsembler/edx-docker-conf-demo
$ cd edx-docker-conf-demo
$ docker build -t appsembler/edx-docker-conf-demo .
...
[go grab a coffee ;)]
...
Successfully built a60411244f93
Successfully tagged appsembler/edx-docker-conf-demo:latest
$
```

# Run the container

Now to run a container:

```
$ docker run -it -P appsembler/edx-docker-conf-demo
...
[2018-05-25T23:24:36.614] [INFO] server - Listening on port 8080...
```

Now in a new terminal window, check to see what ports were assigned to the different services.

```
$ docker ps
CONTAINER ID        IMAGE                             COMMAND                  CREATED             STATUS              PORTS                                                                                                NAMES
d465733e74d6        appsembler/edx-docker-conf-demo   "docker-entrypoint.s…"   49 seconds ago      Up 48 seconds       0.0.0.0:32775->3306/tcp, 0.0.0.0:32774->8000/tcp, 0.0.0.0:32773->8001/tcp, 0.0.0.0:32772->8888/tcp   zealous_tesla
```

So the services that are running are as follows:

```
0.0.0.0:32775->3306/tcp  <-- MySQL
0.0.0.0:32774->8000/tcp  <-- LMS
0.0.0.0:32773->8001/tcp  <-- Studio (CMS)
0.0.0.0:32772->8888/tcp  <-- Orion & Gotty
```

Note: the 32xxx ports will differ when you run this command, as these are randomly assigned available ports.

To get to the development environment, you'll want to find the external port that maps to the internal port 8888. In this case, that port is 32772. Open up this URL in your browser.

```
http://localhost:32772/entry.html
```

Again, the port 32772 will be different on your machine, so adjust accordingly.

When you open this URL in your browser, you should see the Orion editor load in the top half of the screen, and it should show the `/openedx` file tree.

In the bottom half of the screen, you should see the Gotty terminal also with `/openedx` as the current directory.

# Start the Open edX services

Supervisor is used to start/stop the services running inside the container. If you run `supervisorctl` you'll see that the LMS and CMS services are stopped by default.

```
supervisorctl output
```

If you want to start the LMS and CMS services, you can use this commenad:

```
$ supervisorctl <stop/start/restart> <lms/cms>
```

So to start the LMS, you would type:

```
$ supervisorctl start lms
```

Similarly, to start the CMS (Studio), you would type:

```
$ supervisorctl start cms
```

