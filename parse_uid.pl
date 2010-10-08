#!/usr/bin/perl

use strict;

use Data::Dumper;
use XML::LibXML;
use File::Basename;
use File::Basename;
$Data::Dumper::Sortkeys=1;

my $file = shift;
my($filename, $dir, $suffix) = fileparse($file, qr/\.[^.]*/);
my $savefile  = "$dir/$filename.xml";

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

sub addvalues {
    my ($name, $val, $attr) = @_;
    return if $val eq '';
    if (! defined $attr) {
	$attr = "defaults";
	my $exists = 0;
	foreach my $key (sort keys %$var_h){
	    if (exists $var_h->{$key}->{$name}) {
# 		$var_h->{$key}->{$name} = $var_h->{$key}->{$name}." && ".$val;
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
    die "val already exists $name: old = $var_h->{$attr}->{$name}, new = $val\n" if exists $var_h->{$attr}->{$name};
    $var_h->{$attr}->{$name} = $val;
#     $attr = "wizard" if $attr ne "installer" && $attr ne "defaults";
#     $var_h1->{$attr}->{$name} = $val;
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
		if ($txt !~ m/^\$[VJ]\((.*?)\)/ ) {
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

sub printComponent {
    my $node = shift;
    $count++;

    my @q_node = $node->findnodes('displayName');
    die "many names for action.\n" if ( (scalar @q_node) > 1);
    print MYFILE "\n", "\t"x$count,"<Component>", $q_node[0]->textContent,",id ",$node->getAttributeNode("id")->value,"\n";

    my @cond = condition ($node);
#perl ./parse_uid.pl J2EEApplications.uip | cut -d\= -f 2 | sort | uniq

    foreach my $anode ($node->findnodes('action')) {
	my @name_node = $anode->findnodes('displayName');
	die "many names for action.\n" if ( (scalar @name_node) > 1);
	print MYFILE "\t"x($count+1),"<Action> ",$name_node[0]->textContent,"\n";



	my @excl = ();
	foreach my $file_node ($anode->findnodes('property[@name="files"]/arrayItem/property')) {
	    my $attr_name = $file_node->getAttribute("name");
	    next if ($attr_name ne "fileName" && $attr_name ne "excludePattern");
	    push @excl,$file_node->textContent if $attr_name eq "excludePattern";
	    if ($attr_name eq "fileName") {
		print MYFILE "\t"x($count+2),"<Files>",$file_node->textContent,"<\/Files>\n" if $file_node->textContent ne "";
		foreach my $excl_item (@excl) {
		    my @excl_split = split ';', $excl_item;
		    foreach my $excl_split_item (@excl_split) {
			my $excluding = $excl_split_item;
			my $qas = $file_node->textContent;
			$excluding =~ s/\^/$qas\//;
			print MYFILE "\t"x($count+2),"<Files_excl>",$excluding,"<\/Files_excl>\n" if $file_node->textContent ne "";
		    }
		}
		@excl = ();
	    }
	}

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
# die "naspa rau".Dumper(@q)."\n" if (@q>1);

	    my $single_var = {};
	    foreach my $key_ (keys %$var_h) {
		foreach my $key (keys %{$var_h->{$key_}}) {
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
			if (exists $b->{$a} ){
			    $needed->{$a} = $b->{$a};
			}
		    }
		    if ($needed->{$a} eq '' ){
			foreach my $key_ (keys %$var_h) {
			    foreach my $key (keys %{$var_h->{$key_}}) {
				if ($key eq $a){
				    $needed->{$a} .= " && ".$var_h->{$key_}->{$key};
				}
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
		$needed->{$a} = join '||',@qqq;
		$q_txt =~ s/\$V\($a\)/$needed->{$a}/;
	    }
	    if ($q_txt =~ m/\$P\(absoluteInstallLocation\),/) {
		$q_txt =~ s/\$P\(absoluteInstallLocation\),/$filename\//;
	    } else {
		$q_txt = "$filename\/$q_txt";
	    }

	    $q_txt =~ s/\$PATH\((.*)\)/$1/;

	    print MYFILE "\t"x($count+2),"<installLocation>$q_txt<\/installLocation>\n";
	    }
	}
	my @name_node = $anode->findnodes('property[@name="name"]');
	my @value_node = $anode->findnodes('property[@name="value"]');
	if ($name_node[0] && $value_node[0]) {
	    my $name = $name_node[0]->textContent; my $val = $value_node[0]->textContent;
	    addvalues ($name, $val, "___")  ;
print "added new values from install: $name = $val\n";
	}
	print MYFILE "\t"x($count+1),"<\/Action>\n";
    }
    print MYFILE "\t"x$count,"<\/Component\>\n";
    $count--;
}


sub printFeature {
    my $node = shift;


    my @q_node = $node->findnodes('displayName');
    die "many names for action.\n" if ( (scalar @q_node) > 1);
    $count++;
    print MYFILE "\n\n", "\t"x$count,"<Feature>",$q_node[0]->textContent,",id ",$node->getAttributeNode("id")->value,"\n";

    foreach my $anode ($node->getChildrenByTagName('component')) {
    printComponent $anode;
    }
    foreach my $anode ($node->getChildrenByTagName('feature')) {
    printFeature $anode;
    }

    print MYFILE "\t"x$count,"<\/Feature\>\n";
    $count--;
}

sub printWizard {
    my $node = shift;
    my $attribute = shift;
    my $prev_attribute=$attribute;

    $attribute .= $node->getAttributeNode('id')->getValue."," if $node->getName ne "wizardRoot";
    foreach my $anode ($node->getChildrenByTagName('wizardBean')) {
    $prev_attribute = printWizard $anode,$attribute;
    }

    my @name_node = $node->findnodes('property[@name="name"]');
    @name_node = $node->findnodes('property[@name="productBeanId"]') if (@name_node==0);
    my @value_node = $node->findnodes('property[@name="value"]');

    die "many names for action.\n" if ( (scalar @name_node) > 1 || (scalar @value_node) > 1);

    addvalues ($name_node[0]->textContent, $value_node[0]->textContent, $prev_attribute) if ($name_node[0] && $value_node[0]);
    return $prev_attribute;

}

die "nasol\n" if (scalar @all_wizards > 1);
printWizard $all_wizards[0],"";

### default values
foreach my $var (@all_vars) {
    foreach my $q ($var->findnodes('row')) {
    my $var = $q->getChildrenByTagName('VARIABLE')->string_value();
    my $val = $q->getChildrenByTagName('VALUE')->string_value();
    addvalues($var, $val);
    }
}

die "nasol\n" if (scalar @all_nodes > 1);
printFeature $all_nodes[0];

# print Dumper($var_h);
close (MYFILE);
