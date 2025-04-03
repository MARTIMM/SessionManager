use v6.d;

use Desktop::Dispatcher::Variables;
use Digest::SHA256::Native;

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::ActionData;

# ID is readable for easy access
has Str $.id;
has Bool $.run-in-group;

has Proc::Async $!process;
has Str $.run-error;
has Str $.run-log;
has Bool $.running;
has Str $!shell;

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
  $!running = False;

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

#-------------------------------------------------------------------------------
method set-shell ( Str:D $!shell ) { }

#-------------------------------------------------------------------------------
method run-action ( ) {     #( Bool $!run-in-group ) {

  # Set temporary variables if any
  $!variables.set-temporary($!temp-variables) if ?$!temp-variables;

  # Set environment variables
  if ? $!env {
    for $!env.keys -> $name {
      %*ENV{$name} = $!env{$name};
    }
  }

  my Str $command = '';
  $command ~= "cd '$!workdir>'\n" if ? $!workdir;
  $command ~= $!cmd if ? $!cmd;
  $command = $!variables.substitute-vars($command);

  my Str $script-name;
  $script-name = '/tmp/' ~ sha256-hex($command) ~ '.shell-script';
  $script-name.IO.spurt($command);

  $!process .= new( $!shell, $script-name);
  $!run-log = '';
  $!run-error = '';

  react {
    whenever $!process.stdout.lines {
      $!run-log ~= "$_\n";
    }

    whenever $!process.stderr {
      $!run-error ~= "$_\n";
    }

    whenever $!process.ready {
      if $_ ~~ Broken {
        $!run-error ~= "Script failed to start"
      }

      else {
        $!run-log ~= "Program started ok, Pid: $_\n";
        $!running = True;
      }
    }

    whenever $!process.start {
      $!run-log ~= "Program finished: exitcode={.exitcode}, signal={.signal}";
      $!running = False;
      done;
    }

#`{{
    whenever $!process.print: “I\n♥\nCamelia\n” {
      $!process.close-stdin
    }
}}
#`{{
    whenever signal(SIGTERM).merge: signal(SIGINT) {
      once {
        $!run-log ~= ‘Signal received, asking the process to stop’;
        $!process.kill;
        whenever signal($_).zip: Promise.in(2).Supply {
            say ‘Kill it!’;
            $!process.kill: SIGKILL
        }
      }
    }
}}
  #`{{
    whenever Promise.in(5) {
      say ‘Timeout. Asking the process to stop’;
      $!process.kill; # sends SIGHUP, change appropriately
      whenever Promise.in(2) {
          say ‘Timeout. Forcing the process to stop’;
          $!process.kill: SIGKILL
      }
    }
  }}
  }

#    "$!shell {$*verbose ?? '-xv ' !! ''}$script-name > /tmp/script.log &"

  # Remove environment variables
  if ? $!env {
    for $!env.keys -> $name {
      %*ENV{$name}:delete;
    }
  }
}


