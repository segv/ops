package App::Ops::Object;
use Modern::Perl;
use Moo;
use Data::Dumper;
use App::Ops::State;
use App::Ops::Logging qw(DEBUG);
use File::Slurp qw(read_file);

has name => (is => 'ro');

sub make_object {
  return App::Ops::Object->new({ name => $_[0] });
}

sub compute_object_precedence_list {
  my ($self) = @_;
  DEBUG("Computing supers for",$self);

  my @supers;

  if ($self->name eq 'obj') {
    @supers = ( make_object("obj") );
  } else {
    my $state = App::Ops::State->new();

    my $name = $self->name;
    if ($name eq 'this') {
      my $state = App::Ops::State->new();
      $name = $state->this;
    }

    my $super = $state->find_file($name . "/super");

    if ($super) {
      my @direct_supers = map { App::Ops::Object->new({ name => $_ }) } grep { chomp; $_; } split(/\n/, read_file($super));

      DEBUG("direct supers",\@direct_supers);

      @supers = ($self, @direct_supers, map { $_->compute_object_precedence_list } @direct_supers);

      my %seen;

      # reverse the list becuase we want to keep the last occurnce of ech class, not the first
      @supers = reverse @supers;
      @supers = grep { if ($seen{$_->name}) { 0 } else { $seen{$_->name} = 1 } } @supers;
      @supers = reverse @supers;
    } else {
      @supers = ( make_object($self->name), make_object("obj") );
    }
  }
  DEBUG("Supers:",\@supers);
  return @supers;
}


1;
