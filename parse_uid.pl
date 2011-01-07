#!/usr/bin/perl

use strict;

use Data::Dumper;
use XML::LibXML;
use XML::Simple;
use File::Basename;
use File::Path qw(make_path remove_tree rmtree);
use Cwd 'abs_path','chdir';
$Data::Dumper::Sortkeys=1;

my $file = shift;
my($filename, $dir, $suffix) = fileparse($file, qr/\.[^.]*/);
# $dir = abs_path($dir);
my $savefile  = "$dir/$filename.res";

open (MYFILE, '>'.$savefile) or die;

my $parser = XML::LibXML->new();
my $tree = $parser->parse_file($file);
my $root = $tree->getDocumentElement;
my @all_vars = $root->findnodes('/isjeProject/section[@name="Database"]/VARIABLE');
my @all_wizards = $root->findnodes('/isjeProject/section[@name="Installer"]/wizardTree/wizardRoot');
my @all_nodes = $root->findnodes('/isjeProject/section[@name="Product"]/productTree/product');

sub printFeature;
sub printAction;
sub printComponent;
sub printWizard;

my $var_h = {};
my $var_h1 = {};
my $count = -1;
my $copy_files_to = {};
my @files_to_be_copied = ();
my @files_to_be_excluded = ();
my $install_path = "";
my @feat = ();
my $files = {};

sub makedir {
    my ($dir, $no_extra) = @_;
    my ($name_user, $pass_user, $uid_user, $gid_user, $quota_user, $comment_user, $gcos_user, $dir_user, $shell_user, $expire_user) = getpwnam scalar getpwuid $<;
    my $err;
    if (defined $no_extra) {
	make_path ("$dir", {error => \$err});
    } else {
	make_path ("$dir", {owner=>"$name_user", group=>"nobody", error => \$err});
    }
    if (@$err) {
	for my $diag (@$err) {
	    my ($file, $message) = %$diag;
	    if ($file eq '') { print "general error: $message.\n"; }
	    else { print "problem unlinking $file: $message.\n"; }
	}
	die "Can't make dir $dir: $!.\n";
    }
}

sub addvalues {
    my ($name, $val, $attr) = @_;

    return if $val eq '';
    if (! defined $attr) {
	$attr = "defaults";
	my $exists = 0;
	foreach my $key (sort keys %$var_h){
	    if (exists $var_h->{$key}->{$name}) {
		$val = $var_h->{$key}->{$name}." && ".$val;
		$exists = 1;
	    }
	}
	if ($exists != 0) {
	    return;
	}
    }


    if ($attr eq "___"){
	my $exists = 0;
	$attr = "installer";
	foreach my $key (sort keys %$var_h){
	    if (exists $var_h->{$key}->{$name} && $val ne '') {
    # 		$var_h->{$key}->{$name} = $var_h->{$key}->{$name}." && ".$val;
		$exists = 1;
		$val = $var_h->{$key}->{$name}." && ".$val;
	    }
	}
	if ($exists != 0) {
	    return;
	}
    }
    die "val already exists $name: old = $var_h->{$attr}->{$name}, new = $val\n" if exists $var_h->{$attr}->{$name} && $var_h->{$attr}->{$name} != $val;
    $var_h->{$attr}->{$name} = $val;
}

sub condition {
    my $node = shift;
    my @cond = ();
    foreach my $anode ($node->findnodes('condition')) {
	print MYFILE "\t"x($count+1),"<Condition> ",$anode->getAttributeNode("id")->value,"\n";
	foreach my $file_node ($anode->findnodes('*')) {
	    foreach my $attr ($file_node->attributes()) {
	    my $txt = $file_node->textContent;
	    if ($attr->value eq "source") {
		print MYFILE "\t"x($count+2),"<source>$txt<\/source>\n" ;
		if ($txt !~ m/^\$[WVJP]\((.*?)\)/ ) {
		    die "not correct: $txt\n" ;
		} else {
		    push @cond, $1;
		}
	    }
	    }
	}
	print MYFILE"\t"x($count+1),"<\/Condition>\n";
    }
    return @cond;
}

sub printInstall {
    my ($anode, $feat_id, @cond) = @_;
    $install_path = "";

    my @q_node = $anode->findnodes('property[@name="installLocation"]');
    die "many names for action.\n" if ( (scalar @q_node) > 1);
    if (@q_node){
	my $needed = {};
	my $txt = $q_node[0]->textContent;
	my $q_txt = $txt;
	while ($txt =~ m/(\$V\((.*?)\))/gs) {
	    $needed->{$2} = "";
	}

	my @all = ();
	my @q = ();
	if (@cond >0){
	    foreach my $key (keys %$var_h){
		foreach my $cnd (@cond){
		    if (exists $var_h->{$key}->{$cnd} &&
			    ($var_h->{$key}->{$cnd} eq "true" || $var_h->{$key}->{$cnd} eq "Y")){
			push @all, $var_h->{$key};
			push @q, $cnd;
		    }
		}
	    }
	}

	my $single_var = {};
	foreach my $key_ (keys %$var_h) {
	    foreach my $key (keys %{$var_h->{$key_}}) {
		### remove duplicate variables
		if (exists $single_var->{$key}){
		    $single_var->{$key} = "NOOOOS";
		} else {
		    $single_var->{$key} = $var_h->{$key_}->{$key};
		}
	    }
	}

	foreach my $key (keys %$single_var) {
	    delete $single_var->{$key} if $single_var->{$key} eq "NOOOOS";
	}
	my $remaining = {};

	foreach my $a (keys %$needed){
	    if (exists $single_var->{$a} ){
		$needed->{$a} = $single_var->{$a};
	    } else {
		foreach my $b (@all) {
		    if (exists $b->{$a}){
			$needed->{$a} = $b->{$a};
		    }
		}
		if ($needed->{$a} eq '' ){
		    foreach my $key_ (keys %$var_h) {
			if (exists $var_h->{$key_}->{$feat_id} && exists $var_h->{$key_}->{$a}){
die "cocot 3a: $needed->{$a} = $var_h->{$key_}->{$a}\n" if $var_h->{$key_}->{$feat_id} ne "true";
die "cocot 3b: $needed->{$a} = $var_h->{$key_}->{$a}\n" if exists $needed->{$a} && $needed->{$a} ne '' && $needed->{$a} ne $var_h->{$key_}->{$a};
			    $needed->{$a} = $var_h->{$key_}->{$a};
			}
		    }
		}
	    }
	}

	if ($txt ne "" ){
	    print MYFILE "\t"x($count+2),"<installLocation>$q_txt<\/installLocation>\n";
	    foreach  my $a (keys %$needed) {
		my @qqq = split ' && ',$needed->{$a};
		my %hash   = map { $_, 1 } @qqq;
		@qqq = keys %hash;
		@qqq = grep /\S/, @qqq;
die "cocot 2\n"if (scalar @qqq > 1);
		$needed->{$a} = join '||',@qqq;
		$q_txt =~ s/\$V\($a\)/$needed->{$a}/;
	    }
	    if ($q_txt =~ m/\$P\(absoluteInstallLocation\),/) {
		$q_txt =~ s/\$P\(absoluteInstallLocation\),/$filename\//;
	    } else {
		$q_txt = "$filename\/$q_txt";
		$q_txt =~ s/,/\//g;
	    }

	    $q_txt =~ s/\$PATH\((.*)\)/$1/;
	    $q_txt =~ s/\/+/\//g;
	    print MYFILE "\t"x($count+2),"<installLocation>$q_txt<\/installLocation>\n";
	    $install_path = $q_txt;
	}
    }
}
sub printFiles {
    my $anode = shift;
    foreach my $file_node ($anode->findnodes('property[@name="files"]/arrayItem')) {
	my $crt_files_to_be_copied = "";
	my $subdirs = 0;
	my $excl = "";
	foreach my $afile_node ($file_node->findnodes('property')) {
	    my $attr_name = $afile_node->getAttribute("name");
	    next if ($attr_name ne "fileName" && $attr_name ne "excludePattern" && $attr_name ne "includeSubdirs");
	    $subdirs = 1 if $attr_name eq "includeSubdirs" && $afile_node->textContent() =~ m/^true$/i;
	    if ($attr_name eq "fileName") {
		print MYFILE "\t"x($count+2),"<Files>",$afile_node->textContent,"<\/Files>\n" if $afile_node->textContent ne "";
		$crt_files_to_be_copied = $afile_node->textContent;
	    }

	    $crt_files_to_be_copied =~ s/$/\/ -R/ if ($subdirs);

# 	    next if ! scalar @crt_files_to_be_copied;
	    if ($attr_name eq "excludePattern" && $afile_node->textContent ne "") {
		$excl = $afile_node->textContent;
	    }
	}
	my @excl_split = split ';', $excl;
	foreach my $excl_split_item (@excl_split) {
	    my $excluding = $excl_split_item;
	    $excluding =~ s/\^/\//;
	    my $tmp = $crt_files_to_be_copied;
	    if ($crt_files_to_be_copied =~ m/ -r$/i) {
		$tmp =~ s/ -r$//i;
	    }
	    $excluding = $tmp."/".$excluding;
	    $excluding =~ s/\/+/\//g;
	    print MYFILE "\t"x($count+2),"<Files_excl>",$excl_split_item,"<\/Files_excl>\n";
	    push @files_to_be_excluded, $excluding;
	}

	push @files_to_be_copied, $crt_files_to_be_copied;
    }
}

sub printComponent {
    my ($node, $feat_id) = @_;
    $count++;

    my @q_node = $node->findnodes('displayName');
    die "many names for action.\n" if ( (scalar @q_node) > 1);
    print MYFILE "\n", "\t"x$count,"<Component>", $q_node[0]->textContent,",id ",$node->getAttributeNode("id")->value,"\n";

    my @cond = condition ($node);
    my $contition = join ' && ', @cond;
    my $files = {};

    foreach my $anode ($node->findnodes('action')) {
	my @name_node = $anode->findnodes('displayName');
	die "many names for action.\n" if ( (scalar @name_node) > 1);
	print MYFILE "\t"x($count+1),"<Action> ",$name_node[0]->textContent,"\n";
	printFiles($anode);
	printInstall($anode, $feat_id, @cond);

	my @name_node = $anode->findnodes('property[@name="name"]');
	my @value_node = $anode->findnodes('property[@name="value"]');
	if ($name_node[0] && $value_node[0]) {
	    my $name = $name_node[0]->textContent; my $val = $value_node[0]->textContent;
	    addvalues ($name, $val, "___")  ;
	}
	print MYFILE "\t"x($count+1),"<\/Action>\n";
	$install_path = "$filename/" if ($install_path eq "");
	push(@{ $files->{"cond - ".$contition}->{"inst - ".$install_path}->{'f'} }, @files_to_be_copied) if scalar @files_to_be_copied;
	push(@{ $files->{"cond - ".$contition}->{"inst - ".$install_path}->{'e'} }, @files_to_be_excluded) if scalar @files_to_be_excluded;

	@files_to_be_copied = ();
	@files_to_be_excluded = ();
    }
    print MYFILE "\t"x$count,"<\/Component\>\n";

    $count--;
    return $files;
}

sub insert {
  my ($ref, $head, @tail) = @_;
  if ( @tail ) { insert( \%{$ref->{$head}}, @tail ) }
  else         {            $ref->{$head} = $files      }
}

sub printFeature {
    my $node = shift;
    my ($cond, $excluded, $install) = ();

    my @q_node = $node->findnodes('displayName');
    die "many names for action.\n" if ( (scalar @q_node) > 1);
    $count++;
    print MYFILE "\n\n", "\t"x$count,"<Feature>",$q_node[0]->textContent,",id ",$node->getAttributeNode("id")->value,"\n";
    push @feat, "feat - ".$q_node[0]->textContent;

    foreach my $anode ($node->getChildrenByTagName('component')) {
	my @tmp = $anode->findnodes('displayName');
	$files = printComponent ($anode, $node->getAttributeNode("id")->value);
	insert $copy_files_to, (@feat, "comp - ".$tmp[0]->textContent) if scalar keys %$files;
    }
    foreach my $anode ($node->getChildrenByTagName('feature')) {
	printFeature $anode;
    }
    pop @feat;
    print MYFILE "\t"x$count,"<\/Feature\>\n";
    $count--;
}

sub printWizard {
    my $node = shift;
    my $attribute = shift;
    my $prev_attribute = $attribute;

    $attribute .= $node->getAttributeNode('id')->getValue."," if $node->getName ne "wizardRoot";
    foreach my $anode ($node->getChildrenByTagName('wizardBean')) {
	$prev_attribute = printWizard $anode,$attribute;
    }

    my @name_node = $node->findnodes('property[@name="name"]');
    @name_node = $node->findnodes('property[@name="productBeanId"]') if (@name_node == 0);
    my @value_node = $node->findnodes('property[@name="value"]');

    die "many names for action.\n" if ( (scalar @name_node) > 1 || (scalar @value_node) > 1);
    addvalues ($name_node[0]->textContent, $value_node[0]->textContent, $prev_attribute) if ($name_node[0] && $value_node[0]);
    return $prev_attribute;
}

warn "Start working for $file.\n";
die "nasol\n" if (scalar @all_wizards > 1);

### default values
foreach my $var (@all_vars) {
    foreach my $q ($var->findnodes('row')) {
    my $var = $q->getChildrenByTagName('VARIABLE')->string_value();
    my $val = $q->getChildrenByTagName('VALUE')->string_value();
    addvalues($var, $val);
    }
}
printWizard $all_wizards[0],"";

die "nasol\n" if (scalar @all_nodes > 1);
printFeature $all_nodes[0];

close (MYFILE);

sub hash_to_xmlfile {
    my ($hash, $name, $root_name) = @_;
    $root_name = "out" if ! defined $root_name;
    my $xs = new XML::Simple();
    my $xml = $xs->XMLout($hash,
		    NoAttr => 1,
		    RootName=>$root_name,
		    OutputFile => $name
		    );
}

sub write_file {
    my ($path, $text, $mode) = @_;
    my ($name,$dir,$suffix) = fileparse($path, qr/\.[^.]*/);
    if ($mode =~ m/^w$/i) {
	open (FILE, ">$path") or die "at generic write can't open file $path for writing: $!\n";
    } elsif ($mode =~ m/^a$/i) {
	open (FILE, ">>$path") or die "at generic write can't open file $path for writing: $!\n";
    } else {
	die "";
    }
    print FILE "$text\n";
    close (FILE);
}

my $last_status = "";
sub print_hash {
    my ($hash, $dir) = @_;
    my $tmp = "";
    if (ref($hash)eq "HASH"){
	foreach my $q (keys %$hash){
	    if (ref $hash->{$q}) {
		if ($q =~ m/^feat - /) {
		    $tmp = $q; $tmp =~ s/^feat - //;
# 		    print "new dir for $dir/$tmp.\n";
		    $last_status = "feat";
		    die "dir for feat $tmp already here: $dir/$tmp.\n" if -d "$dir/$tmp";
		    $tmp = "/$tmp/";
		    makedir("$dir/$tmp");
		} elsif ($q =~ m/^comp - /) {
		    $tmp = $q; $tmp =~ s/^comp - //;
# 		    print "new dir for $dir/$tmp.\n";
		    $last_status = "comp";
# 		    die "dir for comp already here: $dir/$tmp.\n" if -d "$dir/$tmp";
		    $tmp = "";
# 		    makedir("$dir/$tmp");
		} elsif ($q =~ m/^cond - /) {
		    $tmp = $q; $tmp =~ s/^cond - //;
		    if ($tmp eq "") {
			$tmp = "defaults";
		    }
# 		    print "new file for $dir/$tmp.\n";
		    $last_status = "cond";
		    if ($tmp ne "defaults"){
# 			die "file for cond already here: $dir/$tmp.\n" if -f "$dir/$tmp";
# 			write_file("$dir/$tmp", "", "a");
		    }
# 		    makedir("$dir/$tmp");
		} elsif ($q =~ m/^inst - /) {
		    $tmp = $q; $tmp =~ s/^inst - //;
		    die "last status for inst is $last_status.\n" if ($last_status ne "cond" && $last_status ne "files");
		    $last_status = "inst";
# 		    die "file already exists: $dir/$tmp.\n" if -f "$dir";
		    write_file("$dir", "inst $tmp", "a");
		    $tmp = "";
# 		    print "\tinstall path $tmp in $dir.\n";
		} elsif ($q =~ m/^f$/) {
# 		    print "files in $dir:".Dumper($hash->{$q});
		    die "last status for files is $last_status.\n" if ($last_status ne "inst" && $last_status ne "exceptions");
		    die "unknown 3:".Dumper($hash) if (ref($hash->{$q}) ne "ARRAY");
		    $last_status = "files";
		    foreach my $file (@{$hash->{$q}}) {
			write_file("$dir", "file $file", "a");
		    }
		    next;
		} elsif ($q =~ m/^e$/) {
# 		    print "files in $dir:".Dumper($hash->{$q});
		    die "last status for files is $last_status.\n" if ($last_status ne "inst" && $last_status ne "files");
		    die "unknown 4:".Dumper($hash) if (ref($hash->{$q}) ne "ARRAY");
		    $last_status = "exceptions";
		    foreach my $file (@{$hash->{$q}}) {
			write_file("$dir", "except $file", "a");
		    }
		    next;
		} else {
		    die "unknown 1:".Dumper($hash);
		}
		print_hash($hash->{$q},"$dir$tmp");
	    } else {
		die "Error at $q.\n";
	    }
	}
    } else {
	die "unknown 2:".Dumper($hash);
    }
}

# print Dumper($copy_files_to);
rmtree("$dir/$filename") || die "can't remove dir: $!.\n" if -d "$dir/$filename";
# exit 1;
print_hash($copy_files_to, "$dir/$filename");
