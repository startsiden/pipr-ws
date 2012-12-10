package Pipr::WS;
use Dancer ':syntax';
use Dancer::Plugin::Thumbnail;

our $VERSION = '0.1';

get '/' => sub {
    template 'index';
};

# simple resize
get '/resized/:width/:image' => sub {
  resize param('image') => { w => param 'width' };
};

# simple crop
get '/cropped/:width/:image' => sub {
  crop param('image') => { w => param 'width' };
};

# more complex
get '/thumb/:w/:h/:image' => sub {
  thumbnail param('image') => [
    crop   => { w => 200, h => 200, a => 'lt' },
    resize => { w => param('w'), h => param('h'), s => 'min' },
  ], 
  { format => 'jpeg', quality => 90 };
};

true;
