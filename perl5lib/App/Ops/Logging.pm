package App::Ops::Logging;
use Modern::Perl;
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw( &DEBUG );

sub DEBUG {
  if ($ENV{OPS_DEBUG}) {
    msg(@_);
  }
}

sub Dump {
  my ($object) = @_;
  if (ref($object)) {
    return Data::Dumper->new([ $object ])->Indent(0)->Terse(1)->Dump();
  } else {
    return $object;
  }
}

sub msg {
  my @message = @_;

  my $next = sub {
    my $m = shift(@message);
    if (defined($m)) {
      return Dump($m);
    } else {
      return 'undex';
    }
  };

  my $text = $next->();
  while (@message) {
    if (! ($text =~ /\s\z/ || $message[0] =~ /\A\s/)) {
      $text = $text . " ";
    }
    $text = $text . $next->();
  }
  { local $| = 1; say STDERR $text; }

}

1;
