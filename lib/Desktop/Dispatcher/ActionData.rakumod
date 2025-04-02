use v6.d;

use Desktop::Dispatcher::Variables;
use Digest::SHA256::Native;

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::ActionData;

# ID is readable for easy access
has Str $.id;
has Bool $!run-in-group;

has Str $.tooltip;
has Str $!workdir;
has Hash $!env;
has Str $!script;
has Str $!cmd;

# Picture paths are readable to be able to set on a button or elsewhere
has Str $.picture;
has Str $.overlay-picture;

has Hash $!temp-variables;
has Desktop::Dispatcher::Variables $!variables;

#-------------------------------------------------------------------------------
submethod BUILD ( Str :$!id = '', Hash:D :$raw-action ) {

  $!run-in-group = False;

  $!variables .= instance;

  # Get tooltip text
  $!tooltip = $!variables.substitute-vars($raw-action<t>) if ? $raw-action<t>;

  # Set path to work directory
  $!workdir = $!variables.substitute-vars($raw-action<p>) if ? $raw-action<p>;

  # Set environment as a Hash
  $!env = $raw-action<e> if ? $raw-action<e>;

  # Script to run before command can run
  $!script = $!variables.substitute-vars($raw-action<s>) if ? $raw-action<s>;

  # Set command to run
  $!cmd = $!variables.substitute-vars($raw-action<c>) if ? $raw-action<c>;

  # Set icon on the button.
  $!picture = $!variables.substitute-vars($raw-action<i>)
    if ? $raw-action<i>;

  # Set overlay icon over the button
  $!overlay-picture = $!variables.substitute-vars($raw-action<o>)
    if ? $raw-action<o>;

  # Set temporary variables as a Hash
  $!temp-variables = $raw-action<v> if ? $raw-action<v>;

  # If there is no tooltip, try making it from command
  if ! $!tooltip and ? $!cmd {
    my Str $tooltip = $!cmd;
    $tooltip ~~ s/ \s .* $//;
    $!tooltip = $tooltip;
  }

  # ID from raw hash has precedence of call argument
  $!id = $raw-action<id> if ? $raw-action<id>;

  # If there is no ID, generate an MD5 from the tooltip or a random number
  $!id = sha256-hex($!tooltip // rand.Str) unless ? $!id;
}

#-------------------------------------------------------------------------------
method set-run-in-group ( Bool $!run-in-group ) { }


