use strict;

package AI::Categorizer::Learner::NNetTC;

use AI::Categorizer::Learner;
use base qw(AI::Categorizer::Learner);
use Params::Validate qw(:types);
use File::Spec;

__PACKAGE__->valid_params
  (
   features_kept   => {type => SCALAR, default => 500},
   nn_binary       => {type => SCALAR, default => "nntc"},
   nn_hidden_nodes => {type => SCALAR, default => 50},
   nn_threshold    => {type => SCALAR, default => 500},
   nn_epochs       => {type => SCALAR, default => 5},
   nn_savedelta    => {type => SCALAR, default => 0},
   nn_momentum     => {type => SCALAR, default => 0.5},
   nn_cvexp        => {type => SCALAR, default => 3},
   nn_cv           => {type => SCALAR, default => 200},
   tmpdir          => {type => SCALAR, default => "/tmp"},
  );

sub create_model {
  my $self = shift;

  # Shortcuts
  my $m = $self->{model} = {};
  my $k = $self->knowledge;

  $m->{features} = $k->features;
  my @features = $m->{features}->names;
  my %feature2int = map { $features[$_] => $_ } 0..$#features;

  my @categories = $k->categories;
  my %cat2int = map { $categories[$_]->name => $_ } 0..$#categories;

my $experiment = 'signalg';

  # First create a .net file that nntc will read
  my $vec_file = File::Spec->catfile($self->{tmpdir}, "$experiment.net");
  open my $fh, '>', $vec_file or die "Can't write $vec_file: $!";
  local $| = 1;
  foreach my $doc ($k->documents) {
    print "." if $self->{verbose};
    printf $fh ".%s  %s\n", $doc->name, join(" ", map $cat2int{$_->name}, $doc->categories);
    my $f = $doc->features->normalize->as_hash;
    foreach my $feature (keys %$f) {
      print $fh "$feature2int{$feature}\t$f->{$feature}\n";
    }
  }
  close $fh;
  $m->{vec_file} = $vec_file;
  print "\n" if $self->{verbose};

  # Train the network
  $m->{train_file} = File::Spec->catfile($self->{tmpdir}, "$experiment.ttrn.nnt");
  $m->{cv_file}    = File::Spec->catfile($self->{tmpdir}, "$experiment.cv.nnt");
  $m->{net_tmpfile}= File::Spec->catfile($self->{tmpdir}, "$experiment.net");
  foreach my $a (0.9, 0.5, 0.1) {
    $self->syscall( qq{ $self->{nn_binary} -r $m->{train_file}  -t $m->{cv_file} -e $self->{nn_epochs} } .
		    qq{ -s $self->{nn_savedelta} -n $m->{net_tmpfile} -h $self->{nn_hidden_nodes} } .
		    qq{ -a $a -m $self->{nn_momentum} } );
  }

  # XXX need to incorporate this script
  # Creates "t$THRESHOLD.net" file
  $self->syscall( qq{ /home/halvards/bin/train_nnt.pl -c $self->{nn_cv} -d $self->{tmpdir} -t $self->{nn_threshold} }.
		  qq{ -e $experiment -n $self->{nn_epochs} -h $self->{nn_hidden_nodes} -x $self->{nn_cvexp} -a 0.9 } );
  $m->{net_file} = File::Spec->catfile($self->{tmpdir}, "t$self->{nn_threshold}.net");
}

sub syscall {
  my ($self, $call) = @_;
  print "% $call\n" if $self->{verbose};
  system($call) == 0 or die "FAILED: $?";
}


sub categorize {
  my ($self, $doc) = @_;
}

sub save_state {
  my $self = shift;
  local $self->{knowledge};  # Don't need the knowledge to categorize
  $self->SUPER::save_state(@_);
}

1;
