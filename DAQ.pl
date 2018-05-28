################################################################################################
#
#	File információ:
#
#		File neve: 		microDAQ.pl
#		Készítõ:		Váradi Péter
#		Verzió:			v 1.0
#		Dátum:			2011
#	
#		Információ:		microDAQ projekthez készült PC oldali szoftver
#
####################################### MODULOK #################################################

use Tk::LabFrame;			# A gombokat körül vevõ keret
use Tk;						# Grafikai elemeket tartalmazó modul
use Tk::ProgressBar;		# ADC értékek beolvasása utáni grafikus megjelenítésre
use Tk::Photo;				# Fõablakon lévõ képek megjelenítésére
use Tk::MainWindow;
use Win32::SerialPort;		# Soros port kezelésért felelõs modul
use Win32;
use Tk::SlideSwitch;		# OUT modulhoz kapcsoló gombok
use Tk::BrowseEntry;		# Soros port konfigurálásnál, választási lehetõségek megjelenítésére
use Tk::NoteBook;			# A fõablaknál lévõ fülek

####################################### VÁLTOZÓK, TÖMBÖK ########################################

@baudrate = qw(2400 4800 9600 19200 38400 57600 115200 31250);
@comport = qw(COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 COM9 COM10);
@parity = ('none', 'mark', 'space', 'even', 'odd');
@databits = qw(8 5 6 7);
@stopbits = qw(1 2);
@handshake = qw(none rts dts xoff);

@meresi_ido =qw(21600 600 120 60 10);						#Választható mérési idõk s-ban 
@sample_ido =qw(200 500 1000 2000 5000);			#Mintavételezés ms-onként


@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;
my $localtime = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";

@out1portb=();
my $baud=9600;						# Baud rate beállításáért felelõs változó
my $par=none;						# Paritást megadó változó
my $databit=8;						# Adatbiteket számát tároló változó
my $stopbit=1;						# Stopbitek száma
my $handshake=none;					# Handshake állapota
my $serialout = 0;					# Ebbe kerülnek a soros porton kiküldendõ adatok - karakteres (hexa)
my $portconfigured = 0;				# Ezt vizsgálom, hogy a soros port konfigurálva volt e már
my $adcchannel = 0;					# ADC csatorna számának megadása
my $inputadressread = 0;			# INPUT írásakor - ide kerül a cím (olvasás következik)
my $inputadresswrite = 0;			# INPUT írásakor - ide kerül a cím (írás következik)
my $inputregiodir = 0;				# INPUT írásakor - ide kerül az IODIRn regiszter értéke - karakteres (hexa)
my $inputregpullup = 0;				# INPUT írásakor - ide kerül a GPPUn regiszter értéke - karakteres (hexa)
my $inputregport = 0;  				# INPUT írásakor - ide kerül a GPIOn regiszter értéke - karakteres (hexa)
my $inputportvalue = 0;				# INPUT olvasásakor - ide kerül a beolvasott adat - decimális
my $dacadress = 0;					# DAC írásakor - ide kerül a cím - karakteres (hexa)
my $daccommand = 0;					# DAC írasakor - ide kerül a CMD byte értéke - karakteres (hexa)
my $dacvalue = 0;					# DAC írásakor - ide kerül az adat - karakteres (hexa)
my $CCPvalue = 0;					# CAPTURE olvasásakor a mért idõ a 12Mhz-es órajel szerint (0,083ns/tick)
my $magas_szint = 0;				# Kitöltés magas részének ideje
my $alacsony_szint = 0;				# Kitöltés alacsony részének ideje
my $CCPvalue_time = 0;				# Canvashoz használt változó	
my $alacsony_szint_time;			# Canvashoz használt változó
my $meresi_ido = 120;				# Mérési idõ megadása ADC grafikonnál
my $sample_ido = 1000;	 			# Mintavételezés megadása ADC grafikonnál
my $axisx_scale = 5;				# ADC grafikon: arányos ugrás kiszámolása az mérési és sample idõ FVében
my $axisx=10;						# Ezt inkrementálom az és az x koordinátát adom meg	
my $axisy=500;						# Ezt mérve az y koordinátát adom meg 
my $axisy_elozo=500;				# Itt tárolom az elõzõ y koordinátát
my $elsomeres_adc0_canvas=1;		# A tényleges mérést mehelözõ mérés a helyes grafikon rajzoláshoz

####################################### FÕABLAK #################################################

$foablak = MainWindow->new( -title => "Teszt szoftver v 1.0 - microDAQ");
$foablak->FullScreen();

################################ FÕABLAK - jobb oldal ###########################################

$fulek = $foablak->NoteBook()->pack( -fill=>'both', -side=>right, -expand=>yes, );

$ful1 = $fulek->add( "Sheet 1", -label=>"Vezérlés",);
$ful2 = $fulek->add( "Sheet 2", -label=>"Mérés",);
$ful3 = $fulek->add( "Sheet 3", -label=>"Frekvencia Mérés",);
$ful4 = $fulek->add( "Sheet 4", -label=>"Láb kiosztás",);

my(@pl) = qw/-side right -expand no -fill both/;
my $foablakframe3 = $ful1->Frame->pack(@pl);	

my(@pl) = qw/-side right -expand no -fill x/;
my $foablakframe4 = $ful2->Frame->pack(@pl);

my(@pl) = qw/-side right -expand no -fill both/;
my $foablakframe5 = $ful3->Frame->pack(@pl);

my(@pl) = qw/-side left -expand no -fill both/;
my $foablakframe6 = $ful4->Frame->pack(@pl);

################################ FÕABLAK - bal oldal ############################################

my(@pl) = qw/-side top -expand no -fill both/;
my $foablakframe0 = $foablak->Frame->pack(@pl);	

my(@pl) = qw/-side right -expand no /;
my $foablakframe1 = $foablak->Frame->pack(@pl);	

my(@pl) = qw/-side left -expand no /;
my $foablakframe2 = $foablak->Frame->pack(@pl);	

############### Terminál ###############

	my @pl = qw/ -expand no -padx .3c -pady .3c/;
    my $foablakterminal  = $foablakframe0->LabFrame(
													-label => 'Termin ál'
													)->pack(@pl);
	
				  my $text = $foablakterminal->Text(
													-width => 60, 
													-height => 25, 
													-background =>'black', 
													-foreground =>'green'
													)->pack( -side => 'bottom', -fill => 'both');
													tie *STDOUT, ref $text, $text;
	
							 $foablakframe0->Button(
													-text    => 'Kil ép és',
													-activebackground => 'orange',
													-width   => 20,
													-command => sub {exit;},
													)->pack(qw/-side top -expand yes -pady 2/);
						
###### Soros port konfigurálás #########	
				
	my @pl = qw/ -expand no -padx .5c -pady .5c/;
    my $foablakkonfig = $foablakframe1->LabFrame(
												-label => 'Soros port konfigurálás'
												)->pack(@pl);
									  
					$foablakkonfig->BrowseEntry( 
												-variable => \$com,
												-choices => \@comport,
												-state => 'readonly',
												-label => "  COM port: ",
												)->pack(qw/-side top -expand no -pady 2/);				
						
					$foablakkonfig->BrowseEntry( 
												-variable => \$baud,
												-choices => \@baudrate,
												-state => 'readonly',
												-label => "         Baud: ",
												)->pack(qw/-side top -expand no -pady 2/);
												
					$foablakkonfig->BrowseEntry( 
												-variable => \$par,
												-choices => \@parity,
												-state => 'readonly',
												-label => "      Paritás: ",
												)->pack(qw/-side top -expand no -pady 2/);				
							
					$foablakkonfig->BrowseEntry( 
												-variable => \$databit,
												-choices => \@databits,
												-state => 'readonly',
												-label => "  Adatbitek: ",
												)->pack(qw/-side top -expand no -pady 2/);
						
					$foablakkonfig->BrowseEntry( 
												-variable => \$stopbit,
												-choices => \@stopbits,
												-state => 'readonly',
												-label => " Stop bitek: ",
												)->pack(qw/-side top -expand no -pady 2/);				
												
					$foablakkonfig->BrowseEntry( 
												-variable => \$handshake,
												-choices => \@handshake,
												-state => 'readonly',
												-label => "Handshake:",
												)->pack(qw/-side top -expand no -pady 2/);

						$foablakkonfig->Button	(
												-text => "Kapcsol ód ás",
												-activebackground => 'orange',
												-relief => "raised",
												-command => sub {
																print "- Soros port: 		$com\n";
																print "- Baudrate: 		$baud\n";
																print "- Paritás: 		$par\n";
																print "- Adatbitek száma: 	$databit\n";
																print "- Stop bitek száma: 	$stopbit\n";
																print "- Handshake: 		$handshake\n";
						
																@comsetup=($com,$baud,$par,$databit,$stopbit,$handshake);
																$soros_port = new Win32::SerialPort ("@comsetup[0]", my$quiet) || die "Can't open com3: $^E\n";
																$foablak->update;
																$soros_port->baudrate(@comsetup[1])		|| die "rossz BAUD";
																$soros_port->parity(@comsetup[2])		|| die "rossz Paritas";
																$soros_port->databits(@comsetup[3])		|| die "rossz Adatbit";
																$soros_port->stopbits(@comsetup[4])		|| die "rossz Stopbit";
																$soros_port->buffers(4096,4096)			|| die "rossz Buffer";
																$soros_port->handshake("@comsetup[5]")	|| die "rossz Handshake";
																$soros_port->read_const_time(100);
																#$soros_port->write_settings;
																$portconfigured = 1;
																print "\n Kapcsolat felépítve! \n\n";
																}, 
												)->pack;

									
						@pl = qw/-side bottom -padx 30 -pady 10/;
						$foablakframe2->Label	(
												-image       => $foablak->Photo(-file => ("microdaq.bmp")),
												-borderwidth => 2,
												-relief      => 'sunken',
												)->pack(@pl);


####################################### OUTPUT ##################################################

#FRAMES

my(@pl) = qw/-side top -expand no -padx .5c -pady .5c/;											# Frame 1 - felsõ tulajdonságai
my $foablakframe3frame1 = $foablakframe3->LabFrame(-label => 'Vez érl õpanel')->pack(@pl);		# Frame 1 - felsõ


	#LABELFRAMES
	
    my @pl = qw/-side left -expand no -padx .5c -pady .5c -fill y/;
    my $foablakframe3labframe1  = $foablakframe3frame1->LabFrame(-label => ' OUTPUT ')->pack(@pl);
	

			#BUTTONS

			$foablakframe3labframe1->SlideSwitch(
												-bg          => 'gray',
												-orient      => 'horizontal',
												-command     => sub {if(1 == "@_") {$out1portb[0] = 1;} else{$out1portb[0] = 0;} &_outputsub()},
												-llabel      => [-text => 'CH0 OFF', -foreground => 'blue'],
												-rlabel      => [-text => 'ON',  -foreground => 'blue'],
												-troughcolor => 'tan',
												)->pack(qw/-side top -expand 1/);
										
			$foablakframe3labframe1->SlideSwitch(
												-bg          => 'gray',
												-orient      => 'horizontal',
												-command     => sub {if(1 == "@_") {$out1portb[1] = 2;} else{$out1portb[1] = 0;} &_outputsub()},
												-llabel      => [-text => 'CH1 OFF', -foreground => 'blue'],
												-rlabel      => [-text => 'ON',  -foreground => 'blue'],
												-troughcolor => 'tan',
												)->pack(qw/-side top -expand 1/);
										
			$foablakframe3labframe1->SlideSwitch(
												-bg          => 'gray',
												-orient      => 'horizontal',
												-command     => sub {if(1 == "@_") {$out1portb[2] = 4;} else{$out1portb[2] = 0;} &_outputsub()},
												-llabel      => [-text => 'CH2 OFF', -foreground => 'blue'],
												-rlabel      => [-text => 'ON',  -foreground => 'blue'],
												-troughcolor => 'tan',
												)->pack(qw/-side top -expand 1/);
								
			$foablakframe3labframe1->SlideSwitch(
												-bg          => 'gray',
												-orient      => 'horizontal',
												-command     => sub {if(1 == "@_") {$out1portb[3] = 8;} else{$out1portb[3] = 0;} &_outputsub()},
												-llabel      => [-text => 'CH3 OFF', -foreground => 'blue'],
												-rlabel      => [-text => 'ON',  -foreground => 'blue'],
												-troughcolor => 'tan',
												)->pack(qw/-side top -expand 1/);
										
			$foablakframe3labframe1->SlideSwitch(
												-bg          => 'gray',
												-orient      => 'horizontal',
												-command     => sub {if(1 == "@_") {$out1portb[4] = 16;} else{$out1portb[4] = 0;} &_outputsub()},
												-llabel      => [-text => 'CH4 OFF', -foreground => 'blue'],
												-rlabel      => [-text => 'ON',  -foreground => 'blue'],
												-troughcolor => 'tan',
												)->pack(qw/-side top -expand 1/);
										
			$foablakframe3labframe1->SlideSwitch(
												-bg          => 'gray',
												-orient      => 'horizontal',
												-command     => sub {if(1 == "@_") {$out1portb[5] = 32;} else{$out1portb[5] = 0;} &_outputsub()},
												-llabel      => [-text => 'CH5 OFF', -foreground => 'blue'],
												-rlabel      => [-text => 'ON',  -foreground => 'blue'],
												-troughcolor => 'tan',
												)->pack(qw/-side top -expand 1/);
										
			$foablakframe3labframe1->SlideSwitch(
												-bg          => 'gray',
												-orient      => 'horizontal',
												-command     => sub {if(1 == "@_") {$out1portb[6] = 64;} else{$out1portb[6] = 0;} &_outputsub()},
												-llabel      => [-text => 'CH6 OFF', -foreground => 'blue'],
												-rlabel      => [-text => 'ON',  -foreground => 'blue'],
												-troughcolor => 'tan',
												)->pack(qw/-side top -expand 1/);			

			$foablakframe3labframe1->SlideSwitch(
												-bg          => 'gray',
												-orient      => 'horizontal',
												-command     => sub {if(1 == "@_") {$out1portb[7] = 128;} else{$out1portb[7] = 0;} &_outputsub()},
												-llabel      => [-text => 'CH7 OFF', -foreground => 'blue'],
												-rlabel      => [-text => 'ON',  -foreground => 'blue'],
												-troughcolor => 'tan',
												)->pack(qw/-side top -expand 1/);
										

####################################### INPUT #################################################

#FRAMES


									
	#LABELFRAMES
	

	my @pl = qw/-side left -expand no -padx .5c -pady .5c -fill y/;
    my $foablakframe3labframe2  = $foablakframe3frame1->LabFrame(-label => 'INPUT')->pack(@pl);
	
	@pl = qw/-side top -pady 2/;
    my $labframe2label1 = $foablakframe3labframe2->Label(
														- background => blue,
														- text => 0,
														- foreground => white,
														- borderwidth => 2,
														- relief      => 'sunken',
														- font => "bold"
														)->pack(@pl);
														
	my $labframe2label2 = $foablakframe3labframe2->Label(
														- background => blue,
														- text => 0,
														- foreground => white,
														- borderwidth => 2,
														- relief      => 'sunken',
														- font => "bold"
														)->pack(@pl);
														
    my $labframe2label3 = $foablakframe3labframe2->Label(
														- background => blue,
														- text => 0,
														- foreground => white,
														- borderwidth => 2,
														- relief      => 'sunken',
														- font => "bold"
														)->pack(@pl);
												
    my $labframe2label4 = $foablakframe3labframe2->Label(
														- background => blue,
														- text => 0,
														- foreground => white,
														- borderwidth => 2,
														- relief      => 'sunken',
														- font => "bold"
														)->pack(@pl);
														
    my $labframe2label5 = $foablakframe3labframe2->Label(
														- background => blue,
														- text => 0,
														- foreground => white,
														- borderwidth => 2,
														- relief      => 'sunken',
														- font => "bold"
														)->pack(@pl);
														
    my $labframe2label6 = $foablakframe3labframe2->Label(
														- background => blue,
														- text => 0,
														- foreground => white,
														- borderwidth => 2,
														- relief      => 'sunken',
														- font => "bold"
														)->pack(@pl);
														
    my $labframe2label7 = $foablakframe3labframe2->Label(
														- background => blue,
														- text => 0,
														- foreground => white,
														- borderwidth => 2,
														- relief      => 'sunken',
														- font => "bold"
														)->pack(@pl);
														
	my $labframe2label8 = $foablakframe3labframe2->Label(
														- background => blue,
														- text => 0,
														- foreground => white,
														- borderwidth => 2,
														- relief      => 'sunken',
														- font => "bold"
														)->pack(@pl);

							
		$foablakframe3labframe2->Button(
										-text    => ' INPUT ',
										-activebackground => 'orange',
										-width   => 15,
										-command => sub { 	
														$inputadresswrite = '4E';
														$inputadressread = '4F' ;
														$inputregiodir = '00';
														$inputregpullup = '0C' ;
														$inputregport = '12' ;
														&_inputallsub();
														&_inputlabel()
														},
										)->pack(qw/-side top -expand yes -pady 1/);


####################################### D/A konverter #################################################

#FRAMES


    my @pl = qw/-side left -expand no -padx .5c -pady .5c -fill y/;
    my $foablakframe3labframe3  = $foablakframe3frame1->LabFrame(-label => 'D/A konverter')->pack(@pl);
	
	my $spines0 = $foablakframe3labframe3->Spinbox	(
													qw/-from 0 -to 5 -increment .02 -format %05.2f -width 10 /,
													)->pack(qw/-side top -pady 5 -padx 10/);
				  
				$foablakframe3labframe3->Button		(
													-text    => 'CH0',
													-activebackground => 'orange',
													-width   => 15,
													-command => sub { 	
																	$dacadress = '5E';
																	$daccommand = '00';
																	$dacvalue = ($spines0->get)*51;
																	&_dacsub();
																	printf("CH0 beállított feszültsége: %.2f V\n\n",($spines0->get));
																	},
													)->pack(qw/-side top -expand yes -pady 1/);


	
	my $spines1 = $foablakframe3labframe3->Spinbox	(
													qw/-from 0 -to 5 -increment .02 -format %05.2f -width 10/,
													)->pack(qw/-side top -pady 5 -padx 10/);
				  
				  $foablakframe3labframe3->Button	(
													-text    => 'CH1',
													-activebackground => 'orange',						
													-width   => 15,
													-command => sub { 	
																	$dacadress = '5E';
																	$daccommand = '01';
																	$dacvalue = ($spines1->get)*51;
																	&_dacsub();
																	printf("CH1 beállított feszültsége: %.2f V\n\n",($spines1->get));
																	},
													)->pack(qw/-side top -expand yes -pady 1/);
				  
				  
	
	my $spines2 = $foablakframe3labframe3->Spinbox	(
													qw/-from 0 -to 5 -increment .02 -format %05.2f -width 10/,
													)->pack(qw/-side top -pady 5 -padx 10/);
				  
				  $foablakframe3labframe3->Button	(
													-text    => 'CH2',
													-activebackground => 'orange',
													-width   => 15,
													-command => sub {
																	$dacadress = '5E';
																	$daccommand = '02';
																	$dacvalue = ($spines2->get)*51;
																	&_dacsub();
																	printf("CH2 beállított feszültsége: %.2f V\n\n",($spines2->get));
																	},
													)->pack(qw/-side top -expand yes -pady 1/);
				  
				  
	
	my $spines3 = $foablakframe3labframe3->Spinbox	(
													qw/-from 0 -to 5 -increment .02 -format %05.2f -width 10/,
													)->pack(qw/-side top -pady 5 -padx 10/);
				  
				  $foablakframe3labframe3->Button	(
													-text    => 'CH3',
													-activebackground => 'orange',
													-width   => 15,
													-command => sub { 
																	$dacadress = '5E';
																	$daccommand = '03';
																	$dacvalue = ($spines3->get)*51;
																	&_dacsub();
																	printf("CH3 beállított feszültsége: %.2f V\n\n",($spines3->get));
																	},
													)->pack(qw/-side top -expand yes -pady 1/);
				  
####################################### A/D konverter #################################################


	#LABELFRAMES
	
    my @pl = qw/-side left -expand 0 -padx .5c -pady .5c -fill y/;
    my $foablakframe3labframe4  = $foablakframe3frame1->LabFrame(-label => 'A/D konverter')->pack(@pl);
	
		$foablakframe3labframe4->ProgressBar( 
											-width => 30,
											-from => 0, -to => 5, 
											-blocks => 10, 
											-colors => [0, 'green', 2, 'yellow' , 4, 'red'], 
											-variable => \$progbar1 
											)->pack(-fill => 'x'); 
									
		$foablakframe3labframe4->Button	(
										-text    => 'CH0',
										-activebackground => 'orange',
										-width   => 20,
										-command => sub{
														$adcchannel = '1D';
														&_adcsub();
														$progbar1=$adcvalue;
														printf("CH0 mért feszültsége ->  %.3f\n\n" ,$adcvalue);
														},
										)->pack(qw/-side top -expand yes -pady 1/);
	
		$foablakframe3labframe4->ProgressBar( 
											-width => 30,
											-from => 0, -to => 5, 
											-blocks => 10, 
											-colors => [0, 'green', 2, 'yellow' , 4, 'red'], 
											-variable => \$progbar2 
											)->pack(-fill => 'x');
									
		$foablakframe3labframe4->Button	(
										-text    => 'CH1',
										-activebackground => 'orange',
										-width   => 20,
										-command => sub{
														$adcchannel = '21';
														&_adcsub();
														$progbar2=$adcvalue;
														printf("CH1 mért feszültsége ->  %.3f\n\n" ,$adcvalue);
														},
										)->pack(qw/-side top -expand yes -pady 1/);									
									
		$foablakframe3labframe4->ProgressBar( 
											-width => 30,
											-from => 0, -to => 5, 
											-blocks => 10, 
											-colors => [0, 'green', 2, 'yellow' , 4, 'red'], 
											-variable => \$progbar3 
											)->pack(-fill => 'x'); 
									
		$foablakframe3labframe4->Button	(
										-text    => 'CH2',
										-activebackground => 'orange',
										-width   => 20,
										-command => sub{
														$adcchannel = '25';
														&_adcsub();
														$progbar3=$adcvalue;
														printf("CH2 mért feszültsége ->  %.3f\n\n" ,$adcvalue);
														},
										)->pack(qw/-side top -expand yes -pady 1/);
									
		$foablakframe3labframe4->ProgressBar( 
											-width => 30,
											-from => 0, -to => 5, 
											-blocks => 10, 
											-colors => [0, 'green', 2, 'yellow' , 4, 'red'], 
											-variable => \$progbar4 
											)->pack(-fill => 'x'); 
									
		$foablakframe3labframe4->Button	(
										-text    => 'CH3',
										-activebackground => 'orange',
										-width   => 20,
										-command => sub{
														$adcchannel = '19';
														&_adcsub();
														$progbar4=$adcvalue;
														printf("CH3 mért feszültsége ->  %.3f\n\n" ,$adcvalue);
														},
										)->pack(qw/-side top -expand yes -pady 1/);
								
									
									
####################################### PWM #################################################

my(@pl) = qw/-side bottom -expand yes -fill both/;								# Frame 1 tulajdonságai
my $foablakframe3frame2 = $foablakframe3->Frame->pack(@pl);						# Frame 1 - alsó

my(@pl) = qw/-side right -expand yes/;											# Frame 1 tulajdonságai
my $foablakframe3frame2right = $foablakframe3frame2->Frame->pack(@pl);			# Frame 1 - alsó jobb

my(@pl) = qw/-side left -expand yes -fill both/;								# Frame 1 tulajdonságai
my $foablakframe3frame2left = $foablakframe3frame2->Frame->pack(@pl);			# Frame 1 - alsó bal

    my @pl = qw/-side left -expand 0 -padx .5c -pady .5c -fill both/;
    my $foablakframe3labframe5  = $foablakframe3frame2left->LabFrame(-label => ' PWM ')->pack(@pl);
												
     my $frekvencia = $foablakframe3labframe5->Scale( 
													-orient => vertical,
													-length => 200,
													-from => 100,
													-to => 20, 
													-tickinterval => 10, 
													-resolution   => 10,
													-command => sub{},
													-variable => \$scale1,
													-label    => 'PWM period - kHz',
													);
												 
												 
	my $kitoltes = $foablakframe3labframe5->Scale	( 
													-orient => vertical,
													-length => 200,
													-from => 90,
													-to => 10, 
													-tickinterval => 10, 
													-resolution   => 10,
													-command => sub{},
													-variable => \$scale2,
													-label    => 'Kitöltés - %',
													);
																				
												 
				$foablakframe3labframe5->Button	(
												-text    => 'PWM !',
												-activebackground => 'orange',
												-width   => 20,
												-command => sub	{
																&_PWMsub();
																},
												)->pack(qw/-side bottom -expand yes -pady 1/);
								
    $frekvencia->set(50);
	$kitoltes  ->set(50);
	$frekvencia->pack(qw/-side left -expand yes -anchor c/);
	$kitoltes->pack(qw/-side right -expand yes -anchor c/);

####################################### KÉP #################################################
	
	@pl = qw/-side right -expand yes -anchor c/;
	$foablakframe3frame2right->Label(
									-image       => $foablakframe3frame2right->Photo(-file => ("labkiosztaskicsi.bmp")),
									-borderwidth => 0,
									-relief      => 'sunken',
									)->pack(@pl);
						
####################################### Mérés #################################################	

$canvas=$foablakframe4->Canvas	(
								-width=>'600', 
								-height=>'540'
								)->pack(-expand => 1, -side=>'top');


$canvas->createLine(500,500,10,500,10,0, -width=>'2', -arrow=>'both');

$canvas->createText	(20, 15, 
                    -fill => 'black',
					-text => 'V',
					-font => 'big',
					-font => '-*-Helvetica-Medium-R-Normal--*-150-*-*-*-*-*-*',
					);
					
$canvas->createText	(510, 510, 
					-fill => 'black',
					-text => 't' ,
					-font => 'big',
					-font => '-*-Helvetica-Medium-R-Normal--*-150-*-*-*-*-*-*',
					);

$canvas->createText	(5, 500, 
					-fill => 'black',
					-text => '0' ,
					-font => 'big',
					-font => '-*-Helvetica-Medium-R-Normal--*-100-*-*-*-*-*-*',
					);
					
$canvas->createText	(5, 400, 
					-fill => 'black',
					-text => '1' ,
					-font => 'big',
					-font => '-*-Helvetica-Medium-R-Normal--*-100-*-*-*-*-*-*',
					);
					
$canvas->createText(5, 300, 
					-fill => 'black',
					-text => '2' ,
					-font => 'big',
					-font => '-*-Helvetica-Medium-R-Normal--*-100-*-*-*-*-*-*',
					);
					
$canvas->createText(5, 200, 
					-fill => 'black',
					-text => '3' ,
					-font => 'big',
					-font => '-*-Helvetica-Medium-R-Normal--*-100-*-*-*-*-*-*',
					);
					
$canvas->createText(5, 100, 
					-fill => 'black',
					-text => '4' ,
					-font => 'big',
					-font => '-*-Helvetica-Medium-R-Normal--*-100-*-*-*-*-*-*',
					);

$canvas->createText(5, 5, 
					-fill => 'black',
					-text => '5' ,
					-font => 'big',
					-font => '-*-Helvetica-Medium-R-Normal--*-100-*-*-*-*-*-*',
					);					
					

$canvas->createLine(500,450,10,450, -width=>'1', -fill=>'grey');
$canvas->createLine(500,400,10,400, -width=>'1', -fill=>'grey');
$canvas->createLine(500,350,10,350, -width=>'1', -fill=>'grey');
$canvas->createLine(500,300,10,300, -width=>'1', -fill=>'grey');
$canvas->createLine(500,250,10,250, -width=>'1', -fill=>'grey');
$canvas->createLine(500,200,10,200, -width=>'1', -fill=>'grey');
$canvas->createLine(500,150,10,150, -width=>'1', -fill=>'grey');
$canvas->createLine(500,100,10,100, -width=>'1', -fill=>'grey');
$canvas->createLine(500,50,10,50, 	-width=>'1', -fill=>'grey');
$canvas->createLine(500,0,10,0, 	-width=>'1', -fill=>'grey');


	my @pl = qw/-side left -expand no -padx .5c -pady .5c/;
    my $canvaskonfig = $foablakframe4->LabFrame	(
												-label => 'Mérés konfigurálása'
												)->pack(@pl);
									  
					$canvaskonfig->BrowseEntry	( 
												-variable => \$meresi_ido,
												-choices => \@meresi_ido,
												-state => 'readonly',
												-label => "  Mérés hossza - s     ",
												)->pack(qw/-side top -expand no -pady 2/);				
						
					$canvaskonfig->BrowseEntry	( 
												-variable => \$sample_ido,
												-choices => \@sample_ido,
												-state => 'readonly',
												-label => " Mintavételezés [ms]",
												)->pack(qw/-side top -expand no -pady 2/);
												
						$foablakframe4->Button	(
												-text    => 'Start',
												-background => 'green',
												-activebackground => 'orange',
												-width   => 15,
												-command => sub{
																$rpt=$canvas->repeat($sample_ido,\&_adcch0_sub);		
																},
												)->pack(qw/-side left -expand yes -padx 10 /);
								
						$foablakframe4->Button	(
												-text    => 'Stop',
												-background => 'red',
												-activebackground => 'orange',
												-width   => 15,
												-command => sub{
																$rpt -> cancel;
																},
												)->pack(qw/-side left -expand yes -padx 10/);	

						$foablakframe4->Button	(
												-text    => 'Törl és',
												-activebackground => 'orange',
												-width   => 15,
												-command => sub{
																&_new_canvas();	
																$elsomeres_adc0_canvas=1;
																},
												)->pack(qw/-side left -expand yes -padx 10/);	


####################################### Frekvencia Mérés #######################################

$fmeres=$foablakframe5->Canvas	(
								-width=>'600', 
								-height=>'320'
								)->pack(-expand => 1, -side=>'top');


$fmeres->createLine(500,300,10,300,10,0, -width=>'2', -arrow=>'both');

$fmeres->createLine(500,280,10,280, -width=>'1', -fill=>'grey');
$fmeres->createLine(500,200,10,200, -width=>'1', -fill=>'grey');

$fmeres->createText	(20, 15, 
                    -fill => 'black',
					-text => 'V',
					-font => 'big',
					-font => '-*-Helvetica-Medium-R-Normal--*-150-*-*-*-*-*-*',
					);
					
$fmeres->createText	(510, 310, 
					-fill => 'black',
					-text => 'Hz' ,
					-font => 'big',
					-font => '-*-Helvetica-Medium-R-Normal--*-150-*-*-*-*-*-*',
					);
					
$fmeres->createText	(5, 200, 
					-fill => 'black',
					-text => '5' ,
					-font => 'big',
					-font => '-*-Helvetica-Medium-R-Normal--*-150-*-*-*-*-*-*',
					);
					
$fmeres->createText	(5, 280, 
					-fill => 'black',
					-text => '0' ,
					-font => 'big',
					-font => '-*-Helvetica-Medium-R-Normal--*-150-*-*-*-*-*-*',
					);
	


		$foablakframe5->Button	(
								-text    => 'Mér és ind ít ása',
								-activebackground => 'orange',
								-width   => 20,
								-command => sub	{
												&_CCPsub();		
												},
								)->pack(qw/-side bottom -expand yes -pady 1/);			


######################################LÁB KIOSZTÁS###############################################


@pl = qw/-side left -padx 50 -pady 50 -expand yes /;
$foablakframe6->Label	(
						-image       => $foablak->Photo(-file => ("labkiosztas.bmp")),
						-borderwidth => 5,
						-relief      => 'sunken',
						)->pack(@pl);								


################################################################################################


print "***     		 microDAQ v1.0   	      ***\n";
print "*** A PC-n futó szoftver a mikrovezérlõvel kommunikál ***\n\n";


print $localtime;
print "\n\n";



####################################### FÜGGVÉNYEK #############################################

MainLoop;
sub _adcch0_sub{
					if(1 == $portconfigured)
					{
						if ($elsomeres_adc0_canvas==1)								# Csinálni kell egy elsõ mérést a grafikon rajzolása elõtt
						{
							$adcchannel = '1D';
							&_adcsub();
							$axisy_elozo = 500 - $adcvalue*100;						# Ezzel beállítjuk elõre axisy_elozo értékét
							$elsomeres_adc0_canvas=0;								# A mérés végén állítjuk az elsõ mérés történtét
						}
						$adcchannel = '1D';
						&_adcsub();													# Mérés függvény hívása
						$axisy = 500 - $adcvalue*100;								# y tengelyen koordináta kiszámolása a feszültség alapján
						$axisx_scale = ((500 / $meresi_ido)*$sample_ido/1000);		# A beálított mérési és sample idõ alapján ennyit ugrik x tengelyen mérésenként ahhoz hogy a kiválasztott idõ alatt érjen végig
						printf("CH0 mért feszültsége ->  %.3f\n\n" ,$adcvalue);
						$canvas->createLine($axisx,$axisy_elozo,$axisx+$axisx_scale,$axisy, -fill=>'blue', -width=>1);
						$axisy_elozo=$axisy;										# Jelenlegi y koordináta eltárolása a következõ rajzolásahoz
						$axisx = $axisx+$axisx_scale;								# x koordináta léptetése a következõ rajzoláshoz
						if($axisx > 495)											# Mérés megszakítása ha elértük a 495. koordinátát x-en
						{
							$rpt->cancel;											# Repeat megszakítása
							$elsomeres_adc0_canvas=1;								# Visszaállítjuk az 1. mérést kérõ kapcsolót
							break;
						}
					}
					
					else
					{
						break;
					}
				}


sub _dacsub 
			{
				if (1 == $portconfigured)
				{
					$hexdac = sprintf("%X", $dacvalue);
					if (16 > $dacvalue)
					{
						$hexdac = "0$hexdac";
					}
					print "DAC hexa címe: $dacadress\n";
					print "DAC hexa command byte: $daccommand\n";
					print "Value (hexa) : $hexdac\n";
			
					$serialout="t";							#Vár 1 karaktert a PIC
					$soros_port->write("$serialout");
					$serialout='#A';						#Switch - case A
					$soros_port->write("$serialout");
			
					$serialout = $dacadress;				#cím
					$soros_port->write("$serialout");
					$serialout = "o";
					$soros_port->write("$serialout");
						
					$serialout = $daccommand;				#command
					$soros_port->write("$serialout");
					$serialout = "o";
					$soros_port->write("$serialout");
						
					$serialout = $hexdac;					#érték
					$soros_port->write("$serialout");
					$serialout = "o";
					$soros_port->write("$serialout");
						
					$serialout = '44';						#n flag
					$soros_port->write("$serialout");
					$serialout = "n";
					$soros_port->write("$serialout");			
				}		
				else
				{
					break;
				}
			}
			

			
			
sub _outputsub 	{
					if (1 == $portconfigured)
					{
						$serialout = $out1portb[0] + $out1portb[1] + $out1portb[2] + $out1portb[3] + $out1portb[4] + $out1portb[5] + $out1portb[6] + $out1portb[7];
						$hexout1 = sprintf("%X", $serialout);
						if (16 > $serialout)
						{
							$hexout1 = "0$hexout1";
						}
						print "Value (hexa) : $hexout1\n";
						if( $serialout == 0) {print "Kimenetek lekapcsolva!\n\n";}
						else {print "Beállított kimenet aktív!\n\n";}
						
						$serialout="t";							#Vár 1 karaktert a PIC
						$soros_port->write("$serialout");		
						$serialout='#B';						#Switch - case B
						$soros_port->write("$serialout");
						
						$serialout = '4E';						#cím
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
						
						$serialout = '01';						#IODIRB
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
						
						$serialout = '00';						#érték
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
						
						$serialout = '40';						#n flag
						$soros_port->write("$serialout");
						$serialout = "n";
						$soros_port->write("$serialout");
						
						$serialout = '4E';						#cím
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
						
						$serialout = '15';						#OLATB
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
						
						$serialout = $hexout1;					#érték
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
						
						$serialout = '40';						#n flag
						$soros_port->write("$serialout");
						$serialout = "n";
						$soros_port->write("$serialout");
					}
					else
					{
						break;
					}
				}
					

sub _inputallsub{
					if (1 == $portconfigured)
					{
						$serialout="t";							#Vár 1 karaktert a PIC
						$soros_port->write("$serialout");
						$serialout='#D';						#Switch - case D
						$soros_port->write("$serialout");
											
						$serialout = $inputadresswrite;			#cím
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
											
						$serialout = $inputregiodir;			#IODIRA
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
											
						$serialout = 'FF';						#érték
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
											
						$serialout = '40';						#n flag
						$soros_port->write("$serialout");
						$serialout = "n";
						$soros_port->write("$serialout");
											
						$serialout = $inputadresswrite;			#cím
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
											
						$serialout = $inputregpullup;			#GPPUA
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
											
						$serialout = 'FF';						#érték
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
											
						$serialout = '40';						#n flag
						$soros_port->write("$serialout");
						$serialout = "n";
						$soros_port->write("$serialout");
											
						$serialout = $inputadresswrite;			#cím
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
																
						$serialout = $inputregport;				#GPIOA
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
											
						$serialout = '40';						#n flag
						$soros_port->write("$serialout");
						$serialout = "n";
						$soros_port->write("$serialout");
											
						$serialout = $inputadressread;			#cím - olvasás
						$soros_port->write("$serialout");
						$serialout = "o";
						$soros_port->write("$serialout");
											
						$serialout = '40';						#n flag
						$soros_port->write("$serialout");
						$serialout = "n";
						$soros_port->write("$serialout");
						
						$inputportvalue = $soros_port->read(4) or die "hiba";
						if ( $inputportvalue <= 127 )
						{
							printf ("Bemenetek állapota: 0%b\n\n", $inputportvalue);
						}
						else
						{
							printf ("Bemenetek állapota: %b\n\n", $inputportvalue);						
						}
					}
					else
					{
						break;
					}
				}

					
					
sub _adcsub {
				if (1 == $portconfigured)
				{
					$serialout="t";										#Vár 1 karaktert a PIC
					$soros_port->write("$serialout");
					$serialout='#C';									#Switch - case C
					$soros_port->write("$serialout");
					$serialout= $adcchannel;							#ADC csatorna kiválasztása
					$soros_port->write("$serialout");
									
					$adcvalue = $soros_port->read(10) or die "hiba";	#10bites érték beolvasása
					$adcvalue = $adcvalue/13200;
									
					$foablak->update;
				}
				else
				{
					break;
				}
			}
			
			

sub _PWMsub {
				if (1 == $portconfigured)
				{
					$serialout="t";														#Vár 1 karaktert a PIC
					$soros_port->write("$serialout");
					$serialout='#E';													#Switch - case E
					$soros_port->write("$serialout");
									
					$period = (1/(($frekvencia->get)*1000*4*4*(1/48000000)))-1;			#Skálárol levett érték konverziója a period kiszámolására
					$dutycycle = (4*(1+$period))*1*(($kitoltes->get)/100);				#Ebbõl a megfelelõ kitöltési tényezõ értékének kiszámolása
					printf ("Beállított PWM frekvencia: %d kHZ \n Beállított kitöltés: %d %\n",($frekvencia->get),($kitoltes->get) );
									
					$hexperiod = sprintf("%X", $period);								#Hexa konverzió
					if (16 > $period)
					{
						$hexperiod = "0$hexperiod";
					}
					print "Periódus hexa értéke: $hexperiod\n";
									
					$hexdutycycle = sprintf("%X", $dutycycle);
					if (16 > $dutycycle)
					{
						$hexdutycycle = "000$hexdutycycle";
					}
					elsif(255 > $dutycycle)
					{
						$hexdutycycle = "00$hexdutycycle";
					}
					else
					{
						$hexdutycycle = "0$hexdutycycle";
					}
													
					print "Duty cycle hexa értéke: $hexdutycycle\n\n";
									
					$serialout = $hexperiod;							
					$soros_port->write("$serialout");
					$serialout= $hexdutycycle ;						
					$soros_port->write("$serialout");
				}
													
				else
				{
					break;
				}
			}
			
			
sub _CCPsub {
				if (1 == $portconfigured)
				{
					$fmeres->delete('all');
									
					$fmeres->createLine(500,300,10,300,10,0, -width=>'2', -arrow=>'both');

					$fmeres->createLine(500,280,10,280, -width=>'1', -fill=>'grey');
					$fmeres->createLine(500,200,10,200, -width=>'1', -fill=>'grey');
									
					$fmeres->createText(20, 15, 
										-fill => 'black',
										-text => 'V',
										-font => 'big',
										-font => '-*-Helvetica-Medium-R-Normal--*-150-*-*-*-*-*-*',
										);
														
					$fmeres->createText(510, 310, 
										-fill => 'black',
										-text => 'Hz' ,
										-font => 'big',
										-font => '-*-Helvetica-Medium-R-Normal--*-150-*-*-*-*-*-*',
										);
														
					$fmeres->createText(5, 200, 
										-fill => 'black',
										-text => '5' ,
										-font => 'big',
										-font => '-*-Helvetica-Medium-R-Normal--*-150-*-*-*-*-*-*',
										);
														
					$fmeres->createText(5, 280, 
										-fill => 'black',
										-text => '0' ,
										-font => 'big',
										-font => '-*-Helvetica-Medium-R-Normal--*-150-*-*-*-*-*-*',
										);
														
					$kuka=$soros_port->read(20);					
									
					$serialout="t";										#Vár 1 karaktert a PIC
					$soros_port->write("$serialout");
					$serialout='#F';									#Switch - case F
					$soros_port->write("$serialout");
									
					$CCPvalue = $soros_port->read(6) or die "hiba";
					$alacsony_szint = $soros_port->read(6) or die "hiba";

					$serialout="t";										#Vár 1 karaktert a PIC
					$soros_port->write("$serialout");
					$serialout='#F';									#Switch - case F
					$soros_port->write("$serialout");
									
					$CCPvalue1 = $soros_port->read(6) or die "hiba";
					$alacsony_szint1 = $soros_port->read(6) or die "hiba";

					$serialout="t";										#Vár 1 karaktert a PIC
					$soros_port->write("$serialout");
					$serialout='#F';									#Switch - case F
					$soros_port->write("$serialout");
									
					$CCPvalue2 = $soros_port->read(6) or die "hiba";
					$alacsony_szint2 = $soros_port->read(6) or die "hiba";
									
					$serialout="t";										#Vár 1 karaktert a PIC
					$soros_port->write("$serialout");
					$serialout='#F';									#Switch - case F
					$soros_port->write("$serialout");
									
					$CCPvalue3 = $soros_port->read(6) or die "hiba";
					$alacsony_szint3 = $soros_port->read(6) or die "hiba";
									
					$serialout="t";										#Vár 1 karaktert a PIC
					$soros_port->write("$serialout");
					$serialout='#F';									#Switch - case F
					$soros_port->write("$serialout");
									
					$CCPvalue4 = $soros_port->read(6) or die "hiba";
					$alacsony_szint4 = $soros_port->read(6) or die "hiba";
									
					$serialout="t";										#Vár 1 karaktert a PIC
					$soros_port->write("$serialout");
					$serialout='#F';									#Switch - case F
					$soros_port->write("$serialout");
									
					$CCPvalue5 = $soros_port->read(6) or die "hiba";
					$alacsony_szint5 = $soros_port->read(6) or die "hiba";


					if ($CCPvalue>$CCPvalue1) {}
					else {$CCPvalue=$CCPvalue1;}
					if ($CCPvalue>$CCPvalue2) {}
					else {$CCPvalue=$CCPvalue2;}
					if ($CCPvalue>$CCPvalue3) {}
					else {$CCPvalue=$CCPvalue3;}
					if ($CCPvalue>$CCPvalue4) {}
					else {$CCPvalue=$CCPvalue4;}
					if ($CCPvalue>$CCPvalue5) {}
					else {$CCPvalue=$CCPvalue5;}
								
									
					if ($alacsony_szint>$alacsony_szint1) {}
					else {$alacsony_szint=$alacsony_szint1;}
					if ($alacsony_szint>$alacsony_szint2) {}
					else {$alacsony_szint=$alacsony_szint2;}
					if ($alacsony_szint>$alacsony_szint3) {}
					else {$alacsony_szint=$alacsony_szint3;}
					if ($alacsony_szint>$alacsony_szint4) {}
					else {$alacsony_szint=$alacsony_szint4;}
					if ($alacsony_szint>$alacsony_szint5) {}
					else {$alacsony_szint=$alacsony_szint5;}
									
					$magas_szint = $CCPvalue - $alacsony_szint;
									
					$szazalek_lo=($alacsony_szint/$CCPvalue)*100;
					$szazalek_hi=100-$szazalek_lo;
					#printf $alacsony_szint;
					#printf $CCPvalue;
									
					if($CCPvalue > 6000)
					{
						# $magas_szint = $CCPvalue - $alacsony_szint;
						# $magas_szint = 1/($magas_szint*0.0000000833);
														
						# $frek_time = $CCPvalue * 0.000833;
						# $high_time = $alacsony_szint * 0.000833;
														
						# $CCPvalue = 1/($CCPvalue*0.0000000833);
						# $alacsony_szint = 1/($alacsony_szint*0.0000000833);
														
						# printf ("Mért frekvencia:: %d Hz \n\n", $CCPvalue);
						# printf ("High: %d Hz \n\n", $alacsony_szint);
						# printf ("Low: %d Hz \n\n", $magas_szint);
														
														
														
														
						#$magas_szint = $CCPvalue - $alacsony_szint;
						#$magas_szint = 1/($magas_szint*0.0000000833);
														
						$frek_time = $CCPvalue * 0.000833*2;
						$high_time = $alacsony_szint * 0.000833*2;
														
						$period=$CCPvalue*0.0000833;
						$frekvencia = 1/($CCPvalue*0.0000000833);
														
														
						#$alacsony_szint = 1/($alacsony_szint*0.0000000833);
						$lo_time=$alacsony_szint*0.0000833;
						$hi_time=$period-$lo_time;
						printf ("Mért frekvencia: %f Hz \n", $frekvencia);
						printf ("Periódusidõ: %f ms \n",$period);
						#printf ("%d % \n",$szazalek);
						printf ("Magas szint: %f ms	%f %\n", $hi_time, $szazalek_hi);
						printf ("Alacsony szint: %f ms	%f % \n\n\n", $lo_time, $szazalek_lo);
					}
									
					else
					{
						# $magas_szint = $CCPvalue - $alacsony_szint;
						# $magas_szint = 1/($magas_szint*0.0000833);
									
						# $frek_time = $CCPvalue * 0.0833;
						# $high_time = $alacsony_szint * 0.0833;
									
						# $CCPvalue = 1/($CCPvalue*0.0000833);
						# $alacsony_szint = 1/($alacsony_szint*0.0000833);
									
						# printf ("Mért frekvencia:: %d kHz \n\n", $CCPvalue);
						# printf ("High: %d kHz \n\n", $alacsony_szint);
						# printf ("Low: %d kHz \n\n", $magas_szint);
									
									
									
									
						#$magas_szint = $CCPvalue - $alacsony_szint;
						#$magas_szint = 1/($magas_szint*0.0000833);
									
						$frek_time = $CCPvalue * 0.0833;
						$high_time = $alacsony_szint * 0.0833;
									
						$period=$CCPvalue*0.0000833;
						$frekvencia = 1/($CCPvalue*0.0000833);
									
						#$alacsony_szint = 1/($alacsony_szint*0.0000000833);
						$lo_time=$alacsony_szint*0.0000833;
						$hi_time=$period-$lo_time;
						printf ("Mért frekvencia: %f kHz \n", $frekvencia);
						printf ("Periódusidõ: %f ms \n",$period);
						#printf ("%d % \n",$szazalek);
						printf ("Magas szint: %f ms	%f %\n", $hi_time, $szazalek_hi);
						printf ("Alacsony szint: %f ms	%f % \n\n\n", $lo_time, $szazalek_lo);
					}
									
					for($axisx2 = 15; $axisx2 <480 ;$axisx2 = $axisx2 + $frek_time)
					{
						$fmeres->createLine($axisx2,280,$axisx2,200,$axisx2 + $high_time,200,$axisx2 + $high_time,280,$axisx2 + $frek_time,280,$axisx2 + $frek_time,200, -width=>'2', -fill=>'blue');
					}				
				}						
										
				else
				{
					break;
				}
			}
			
sub _new_canvas	{
					if(1 == $portconfigured)
					{
						$canvas->delete('all');

						$canvas->createLine(500,500,10,500,10,0, -width=>'2', -arrow=>'both');
						$canvas->createText(20, 15, 
											-fill => 'black',
											-text => 'V',
											-font => 'big',
											-font => '-*-Helvetica-Medium-R-Normal--*-150-*-*-*-*-*-*',
											);
															
						$canvas->createText(510, 510, 
											-fill => 'black',
											-text => 't' ,
											-font => 'big',
											-font => '-*-Helvetica-Medium-R-Normal--*-150-*-*-*-*-*-*',
											);

						$canvas->createText(5, 500, 
											-fill => 'black',
											-text => '0' ,
											-font => 'big',
											-font => '-*-Helvetica-Medium-R-Normal--*-100-*-*-*-*-*-*',
											);
															
						$canvas->createText(5, 400, 
											-fill => 'black',
											-text => '1' ,
											-font => 'big',
											-font => '-*-Helvetica-Medium-R-Normal--*-100-*-*-*-*-*-*',
											);
															
						$canvas->createText(5, 300, 
											-fill => 'black',
											-text => '2' ,
											-font => 'big',
											-font => '-*-Helvetica-Medium-R-Normal--*-100-*-*-*-*-*-*',
											);
															
						$canvas->createText(5, 200, 
											-fill => 'black',
											-text => '3' ,
											-font => 'big',
											-font => '-*-Helvetica-Medium-R-Normal--*-100-*-*-*-*-*-*',
											);
															
						$canvas->createText(5, 100, 
											-fill => 'black',
											-text => '4' ,
											-font => 'big',
											-font => '-*-Helvetica-Medium-R-Normal--*-100-*-*-*-*-*-*',
											);

						$canvas->createText(5, 5, 
											-fill => 'black',
											-text => '5' ,
											-font => 'big',
											-font => '-*-Helvetica-Medium-R-Normal--*-100-*-*-*-*-*-*',
											);					
															

						$canvas->createLine(500,450,10,450, -width=>'1', -fill=>'grey');
						$canvas->createLine(500,400,10,400, -width=>'1', -fill=>'grey');
						$canvas->createLine(500,350,10,350, -width=>'1', -fill=>'grey');
						$canvas->createLine(500,300,10,300, -width=>'1', -fill=>'grey');
						$canvas->createLine(500,250,10,250, -width=>'1', -fill=>'grey');
						$canvas->createLine(500,200,10,200, -width=>'1', -fill=>'grey');
						$canvas->createLine(500,150,10,150, -width=>'1', -fill=>'grey');
						$canvas->createLine(500,100,10,100, -width=>'1', -fill=>'grey');
						$canvas->createLine(500,50,10,50, -width=>'1', -fill=>'grey');
						$canvas->createLine(500,0,10,0, -width=>'1', -fill=>'grey');

						$axisx=15;		
						$axisy=500;	 
						$axisy_elozo=500;					
					}
					
					else
					{
						break;
					}
				}
				
sub _inputlabel
				{
					if($inputportvalue & 0b10000000)
					{
						$labframe2label1->configure(-background => red, -text => 1);
					}
					else 
					{
						$labframe2label1->configure(-background => blue, -text => 0);
					}
					
					if($inputportvalue & 0b01000000)
					{
						$labframe2label2->configure(-background => red, -text => 1);
					}
					else 
					{
						$labframe2label2->configure(-background => blue, -text => 0);
					}
					
					if($inputportvalue & 0b00100000)
					{
						$labframe2label3->configure(-background => red, -text => 1);
					}
					else 
					{
						$labframe2label3->configure(-background => blue, -text => 0);
					}
					
					if($inputportvalue & 0b00010000)
					{
						$labframe2label4->configure(-background => red, -text => 1);
					}
					else 
					{
						$labframe2label4->configure(-background => blue, -text => 0);
					}
					
					if($inputportvalue & 0b00001000)
					{
						$labframe2label5->configure(-background => red, -text => 1);
					}
					else 
					{
						$labframe2label5->configure(-background => blue, -text => 0);
					}
					
					if($inputportvalue & 0b00000100)
					{
						$labframe2label6->configure(-background => red, -text => 1);
					}
					else 
					{
						$labframe2label6->configure(-background => blue, -text => 0);
					}
					
					if($inputportvalue & 0b00000010)
					{
						$labframe2label7->configure(-background => red, -text => 1);
					}
					else 
					{
						$labframe2label7->configure(-background => blue, -text => 0);
					}
					
					if($inputportvalue & 0b00000001)
					{
						$labframe2label8->configure(-background => red, -text => 1);
					}
					else 
					{
						$labframe2label8->configure(-background => blue, -text => 0);
					}
				}