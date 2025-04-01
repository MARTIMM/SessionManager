use v6.d;

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::Variable;

my Desktop::Dispatcher::Variable $instance;

has Hash $!variables;
has Hash $!temporary;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!variables = %();
  $!temporary = %();
}

#-------------------------------------------------------------------------------
method instance ( --> Desktop::Dispatcher::Variable ) {
  $instance //= self.new;

  $instance
}

#-------------------------------------------------------------------------------
method add ( Hash:D $variables ) {
  $!variables = %( | $!variables, | $variables);
}

#-------------------------------------------------------------------------------
method set-temporary ( Hash:D $!temporary ) { }

#-------------------------------------------------------------------------------
method substitute-vars ( Str $t --> Str ) {

  my Str $text = $t;

  while $text ~~ m/ '$' $<variable-name> = [<alpha> | \d | '-']+ / {
    my Str $name = $/<variable-name>.Str;

    # Look in the variables Hash
    if $!variables{$name}:exists {
      $text ~~ s:g/ '$' $name /$!variables{$name}/;
    }

    # Look in the temporary Hash
    elsif $!temporary{$name}:exists {
      $text ~~ s:g/ '$' $name /$!temporary{$name}/;
    }

    # Look in the environment
    elsif %*ENV{$name}:exists {
      $text ~~ s:g/ '$' $name /%*ENV{$name}/;
    }

    # Fail and block variable by substituting $ for __
    else {
      note "No substitution yet or variable \$$name" if $*verbose;
      $text ~~ s:g/ '$' $name /___$name/;
    }
  }

  # Not substituted names are replaced by the original variable format
  $text ~~ s:g/ '___' ([<alpha> | <[0..9]> | '-']+) /\$$0/;

  $text
}
