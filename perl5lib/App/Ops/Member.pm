package App::Ops::Member;
use Modern::Perl;
use Moo;
use Data::Dumper;
use App::Ops::State;
use App::Ops::Object;
use App::Ops::Logging qw(DEBUG);
use Getopt::Long;
use File::Slurp qw(read_file);

has object => (is => 'ro');
has method => (is => 'ro');

sub method_spec {
  my ($self) = @_;
  return $self->object->name() . "." . $self->method();
}

around BUILDARGS => sub {
  my $orig  = shift;
  my $class = shift;

  my $args = $class->$orig(@_);

  if ($args->{spec}) {
    my ($object_name, $method) = parse_method_spec($args->{spec});
    if ($object_name && $method) {
      if ($object_name eq 'this') {
        $object_name = App::Ops::State->new->this;
      }
      $args->{object} = App::Ops::Object->new({ name => $object_name });
      $args->{method} = $method;
    } else {
      die "Unable to parse " . $args->{spec} . " as a method spec.";
    }
    DEBUG("Made member with", [ $args->{object}, $args->{method} ],"from",$args->{spec});
  }

  return $args;
};

sub parse_method_spec {
  my ($method_spec) = @_;
  my ($object_name, $method_name);

  if ($method_spec =~ /\A([^.]+)\.(.*?)\z/) {
    $object_name = $1;
    $method_name = $2;
  } elsif ($method_spec =~ /\A([^.]+)\z/) {
    $object_name = $1;
    $method_name = "do";
  } else {
    die "Unable to parse method spec $method_spec";
  }

  return $object_name, $method_name;
}

sub location {
  my ($self) = @_;

  my $state = App::Ops::State->new();

  if ($self->object->name eq 'super') {
    die 'sorry, no super yet';
  } else {
    return $state->find_file($self->object->name . "/" . $self->method);
  }
}

sub get_shebang_line {
  my ($self, $filename) = @_;
  open my $FILE, "<", $filename;
  my $first_chars = "";
  my $bytes = sysread($FILE, $first_chars, 2);
  if ($bytes == 2 && $first_chars eq '#!') {
    my $line = "";
    my $char;
    while (1 == sysread($FILE, $char, 1)) {
      if ($char eq "\x0A" || $char eq "\x0D") {
        return $line;
      }
      $line = $line . $char;
    }
    die "Unable to find end of shebang line in $filename";
  } else {
    # no shebang line"
    return undef;
  }
}

sub compute_applicable_methods {
  my ($self) = @_;
  my @copl = $self->object->compute_object_precedence_list;

  my $before = $self->method . ".before";
  my $after  = $self->method . ".after";
  my $around  = $self->method . ".around";
  my $primary  = $self->method;

  my $methods = { befores => [ ],
                  afters => [ ],
                  arounds => [ ],
                  primaries => [ ] };

  my $state = App::Ops::State->new();

  foreach my $object (@copl) {
    my $meth_file = sub { DEBUG("Checking for ", [ $object->name, $_[0] ] ); return $state->find_file($object->name . "/" . $_[0]); };
    my $member    = sub { return App::Ops::Member->new({ object => $object, method => $_[0] }); };

    push    @{ $methods->{befores} },   $member->($before)  if $meth_file->($before);
    push    @{ $methods->{arounds} },   $member->($around)  if $meth_file->($around);
    unshift @{ $methods->{afters} },    $member->($after)   if $meth_file->($after);
    push    @{ $methods->{primaries} }, $member->($primary) if $meth_file->($primary);
  }

  return $methods;
}

sub execute {
  my ($self, @arguments) = @_;

  DEBUG("Executing self",$self);

  my $filename = $self->location;

  DEBUG("location",\$filename);

  if (! -e $filename) {
    die "Sorry, no location found for " . $self->method_spec;
  }

  my $state = App::Ops::State->new();

  my $shebang = $self->get_shebang_line($filename);

  my $ret;

  {
    local $ENV{OPS_METHOD} = $self->method_spec . "@" . $filename;

    if ($shebang) {
      DEBUG("shebang'ing", [ $filename, @arguments ]);
      my @shebang = split(/\s+/, $shebang);
      my $program = $shebang[0];
      $ret = system { $program } @shebang, $filename, @arguments;
    } elsif (-x $filename) {
      DEBUG("exec'ing", [ $filename, @arguments ]);
      $ret = system $filename, @arguments;
    } else {
      die "Unable to execute $filename";
    }
  }

  $ret = $ret >> 8;
  DEBUG("Exit with $ret");
  return $ret;
}

sub do_call {
  my ($self, @arguments) = @_;
  DEBUG("do_call", $self, [ @arguments ]);
  my @methods = $self->compute_applicable_methods;

  my $state = App::Ops::State->new();

  $state->this($self->object->name);

  my $methods = $self->compute_applicable_methods;

  if (scalar(@{ $methods->{primaries} }) == 0) {
    die "No primary methods for " . $self->method_spec;
  }

  $state->original_arguments(\@arguments);

  $state->next_methods({ arounds => [ map { $_->method_spec } @{ $methods->{arounds} } ],
                         primaries => [ map { $_->method_spec } @{ $methods->{primaries} } ] });

  my $ret;
  if (@{ $methods->{arounds} }) {
    $ret = do_call_next_method();
  } else {

    foreach my $before (@{ $methods->{befores} }) {
      DEBUG("Before", $before);
      $before->execute(@arguments);
    }

    $ret = do_call_next_method();

    foreach my $after (@{ $methods->{afters} }) {
      DEBUG("After", $after);
      $after->execute(@arguments);
    }
  }

  return $ret;
}

sub do_call_next_method {
  my @arguments = @_;
  DEBUG("do_call_next_method", \@arguments);

  my $state = App::Ops::State->new();

  if (@arguments) {
    $state->original_arguments([ @arguments ]);
  } else {
    @arguments = @{ $state->original_arguments };
  }

  my $methods = $state->next_methods;
  my $ret;

  my $next;

  if (@{ $methods->{arounds} }) {
    $next = shift(@{ $methods->{arounds} });
    DEBUG("Around", $next);
  } elsif (@{ $methods->{primaries} }) {
    $next = shift(@{ $methods->{primaries} });
    DEBUG("Primary", $next);
  } else {
    die "No next method for " . $ENV{OPS_METHOD};
  }

  $state->next_methods($methods);

  return App::Ops::Member->new({ spec => $next })->execute(@arguments);
}

sub do_prop {
  my ($self, @arguments) = @_;
  my $z = 0; # end with null char
  my $n = 0; # don't output anything after the property
  my $e = 0; # exit with 1 if not found
  my $q = 0; # suppress error message
  my $f = 0; # output the filename of the property

  Getopt::Long::Configure("bundling");
  GetOptions("z" => \$z, "n" => \$n, "e" => \$e, "q" => \$q, "f" => \$f);

  my $location = $self->location() || "";
  if ($e && ! $location) {
    if (! $q) {
      print $self->method_spec . " not found\n";
    }
    return 1;
  }
  if ($f) {
    print $location;
    if (! $n) {
      print "\n";
    }
  } else {
    print read_file $location;
  }
  return 0;
}

1;
