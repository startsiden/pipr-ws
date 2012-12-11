pipr-ws
=======

Picture provider. Basically resizes external images and caches them.

Usage:

  http://pipr.opentheweb.org/hvordan/resized/200x/http://polarboing.com/themes/easter/images/pb_easter_logo.png

Deployment:

  See http://search.cpan.org/~xsawyerx/Dancer-1.3110/lib/Dancer/Deployment.pod for deployment

Tests:
  prove -lv t

Development:
  bin/app.pl

Production:
  bin/app.pl --environment production
