package App::Ops::State;
use Modern::Perl;
use Moo;
use JSON::PP;
use Cwd qw(abs_path);
use App::Ops::Logging qw(DEBUG);

sub state {
  my ($self, $new_state) = @_;
  if ($new_state) {
    $ENV{OPS_STATE} = encode_json($new_state);
  }
  my $state = decode_json($ENV{OPS_STATE});
  die "Unable to parse STATE, $ENV{OPS_STATE}" unless $state;
  return $state;
}

sub this {
  my ($self, $new_this) = @_;
  if ($new_this) {
    my $state = $self->state;
    $state->{this} = $new_this;
    $self->state($state);
  }
  $self->state()->{this};
}

sub next_methods {
  my ($self, $new_next_methods) = @_;
  if ($new_next_methods) {
    my $state = $self->state;
    $state->{next_methods} = $new_next_methods;
    $self->state($state);
  }
  $self->state()->{next_methods};
}

sub original_arguments {
  my ($self, $new_arguments) = @_;
  if ($new_arguments) {
    my $state = $self->state;
    $state->{original_arguments} = $new_arguments;
    $self->state($state);
  }
  $self->state()->{original_arguments};
}

sub find_file {
  my ($self, $filename) = @_;
  foreach my $path (@{ $self->state->{path} }) {
    my $filename = "$path/$filename";
    DEBUG("File",[ $filename ]);
    if (-e $filename) {
      DEBUG("found",[ $filename ]);
      return abs_path($filename);
    }
  }
  return 0;
}

1;
