pipr-ws
=======

Picture provider. Resizes external images and caches them.

Pipr-ws is set up to acept URLs in the form of http://pipr-ws/&lt;consumer_id>/&lt;action>/(&lt;params>|...)/&lt;url>

It will download the page where the URL points to, cache the result forever, perform an action on it and cache the result of the action forever.

In addition if a URL that is not an image is used, it will try to pick out what seems to be most likely the main image of the page.

The primary cache location is set by the 'cache_dir' key in the configuration file 'config.yml' and it uses the &lt;url> as key

The secondary cache (after resizing or cropping) is defined in the plugin part and uses the full url including the action and params:

````
plugins:
    Thumbnail:
        cache: /tmp/pipr/thumb_cache
        compression: 7
        quality: 50
````

The plugin used to resize is a modified version of Dancer::Plugin::Thumbnail - it uses GD::Image for resizing.

The current configuration is shown together with examples on the root page of the web service.

Example:

````
    abcn   {
        allowed_targets   [
            [0] "http://www.abcnyheter.no",
            [1] "files"
        ],
        prefix   "http://www.abcnyheter.no/",
        sizes    [
            [0] "972x",
            [1] "486x"
        ]
    },
````

Means that at http://pipr-ws/abcn/ the following sizes are allowed to be used with the /resized/ action. Only images that are hosted on
http://www.abcnyheter.no (and relative url 'files') are allowed (allowed_targets), and if a relative URL is given, it will prepend http://www.abcnyheter.no to it (prefix)

For environment specific settings, check the files in the 'enviroments' directory.

The plan is to move to a simpler strictly Plack-based service, but the current one works and we need it out.

Usage:

  http://dev-pipr.startsiden.dev/abcn/resized/972x/http://www.abcnyheter.no/files/drfront/images/2014/03/24/c=33,86,617,311;w=680;h=343;72549.jpg

Deployment:

  The current deployment on dev-pipr inclues a varnish front that caches on top of the web service.
  The web service runs as a starman application listenitng to a socket, that nginx communicates to

  The setup uses 'salt' and is available here: http://git.startsiden.no/operations/saltstack/blob/master/products/pipr-ws/backend.sls

  It includes init.d for starman, cronjob for cleaning up cache once a day, varnish setup and nginx setup.

## Running the Pipr application manually on your local

#### Ask guys from operations to add you login to gcr.io
You need a user account in order to pull our base images with docker.

#### Install the `gcloud` command line tool
It can be found here: https://cloud.google.com/sdk/docs/quickstart-mac-os-x

#### Initialize the `gcloud` command line tool
`$ gcloud init`

#### Authenticate docker with Google Cloud Registry
`$ docker login -u _token -p "$(gcloud auth print-access-token)" https://eu.gcr.io`

#### Build and run the server and assets watch
`$ docker-compose up --build`

#### Build and run test
`$ docker-compose -f docker-compose-test.yml up --build`

