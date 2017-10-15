
# 
# This file contains the the scripts which create the Apogee camera GUI. The procedures
# use the C++ API via a wrapper generated by SWIG.
#
#



#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : showstatus
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This routine displays text messages in the status window
#
#  Arguments  :
#
#               msg	-	message text
 
proc showstatus { msg } {
 
#
#  Globals    :		n/a
#  
global NESSIGUI
  if { $NESSIGUI } {
    .status.msg configure -text "$msg"
    update
  } else {
    puts stdout "$msg"
  }
}







#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : choosedir
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure prompts the user to specify a directory using a 
#  flexible GUI interface.
#
#  Arguments  :
#
#               type	-	Calibration type (flat,dark,sky,zero)
#               name	-	Image file name
 
proc choosedir { type name} {
 
#
#  Globals    :
#  
#               CALS	-	Calibration run parmaeters
#               CATALOGS	-	Catalog configurations
#               SCOPE	-	Telescope parameters, gui setup
global CALS CATALOGS SCOPE
   if { $type == "data" } {
     set cfg [tk_chooseDirectory -initialdir $SCOPE(datadir)/$name]
     set SCOPE(datadir) $cfg
     .main.seldir configure -text "$cfg"
   } else {
     set cfg [tk_chooseDirectory -initialdir $CALS(home)/$name]
   }
   if { [string length $cfg] > 0 } {
     if { [file exists $cfg] == 0 } {
        exec mkdir -p $cfg
     }
     switch $type {
         calibrations {set CALS($name,dir) $cfg }
         catalogs     {set CATALOGS($name,dir) $cfg }
     }
   }
}



#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : inspectapi
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure inspects the set of wrapper commands generated by SWIG.
#  These commands will be of the form Object_somename_set/get, and the
#  instance variable wrappers will be of the form -m_somename.
#  This predictable nomenclature is exploited to parse the set of 
#  all available commands, and seek out all those associated with 
#  the named C++ object type.
#
#  This ensures that when facilities are added to the C++ code, only
#  minimal rewrite (if any) will be needed in the tcl code.
#
#  Arguments  :
#
#               object	-	Name of wrapped C++ object
 
proc inspectapi { object } {
 
#
#  Globals    :
#  
#               CCAPIR	-	C++ readable instance variables
#               CCAPIW	-	C++ writable instance variables
global CCAPIR CCAPIW
  set all [info commands]
  foreach i $all { 
     set s [split $i _]
     if { [lindex $s 0] == $object } {
        if { [lindex $s end] == "get" } {
           set name [join [lrange $s 1 [expr [llength $s]-2]] _]
           set CCAPIR($name) cget
        }
        if { [lindex $s end] == "set" } {
           set name [join [lrange $s 1 [expr [llength $s]-2]] _]
           set CCAPIW($name) configure
        }
        if { [lindex $s 1] == "read" } {
           set name [join [lrange $s 1 end] _]
           set CCAPIR($name) method
        }
        if { [lindex $s 1] == "write" } {
           set name [join [lrange $s 1 end] _]
           set CCAPIW($name) method
        }
     }
  }
}






#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : printcamdata
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure loop thru all the items in CAMSTATUS and 
#  prints the current values, primarily for interactive debugging use.
#
#  Arguments  :
#
#               id	-	Camera id (for multi-camera use) (optional, default is 0)
 
proc printcamdata { {id 0} } {
 
#
#  Globals    :
#  
#               CAMERAS	-	Camera id's
#               CAMSTATUS	-	Current values of camera variables
global CAMERAS CAMSTATUS
    foreach i [lsort [array names CAMSTATUS]] { 
        puts stdout "$i = $CAMSTATUS($i)"
    }
}





#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : refreshcamdata
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure interrogates the current value of all instance variables
#  exported from the C++ api. Values are stored into the global array
#  CAMSTATUS for easy acces from the tcl code
#
#  Arguments  :
#
#               id	-	Camera id (for multi-camera use) (optional, default is 0)
 
proc refreshcamdata { {id 0} } {
 
#
#  Globals    :
#  
#               CAMSTATUS	-	Current values of camera variables
#               CCAPIR	-	C++ readable instance variables
#               CCAPI	-	Generic C++ object names
#               CAMERAS	-	Camera id's
#               CONFIG	-	GUI configuration
global CAMSTATUS CCAPIR CCAPI CAMERAS CONFIG
    set camera $CAMERAS($id)
    foreach i [lsort [array names CCAPIR]] { 
       if { $CCAPIR($i) == "method" } {
          if { $i != "read_LedState" } {
            set CAMSTATUS([string range $i 5 end]) [$camera $i]
            set name [string range $i 5 end]
            if { [info exists CCAPI($name)] } {
               set CONFIG($CCAPI($name)) $CAMSTATUS($name)
            }
          } else {
            set CAMSTATUS([string range $i 5 end]) "[$camera $i 0] [$camera $i 1]"
          }
       }
       if { $CCAPIR($i) == "cget" } {
          set name [string range $i 2 end]
          set CAMSTATUS($name) [$camera cget -$i]
          if { [info exists CCAPI($name)] } {
             set CONFIG($CCAPI($name)) $CAMSTATUS($name)
          }
       }
    }
}



proc refreshcamdata { {id 0} } {
 
#
#  Globals    :
#  
#               CAMSTATUS	-	Current values of camera variables
#               CCAPIR	-	C++ readable instance variables
#               CCAPI	-	Generic C++ object names
#               CAMERAS	-	Camera id's
#               CONFIG	-	GUI configuration
global CAMSTATUS CCAPIR CCAPI CAMERAS CONFIG CAMPROPERTIES
   set camera $CAMERAS($id)
   foreach item $CAMPROPERTIES {
       set n [string range $item 3 end]
       set CAMSTATUS($n) [$camera $item]
   }
}

set CAMPROPERTIES "GetAvailableMemory GetCameraMode GetCcdAdc12BitGain GetCcdAdc12BitOffset GetCcdAdc16BitGain GetCcdAdcResolution GetCcdAdcSpeed GetCoolerBackoffPoint GetCoolerDrive GetCoolerSetPoint GetCoolerStatus GetDriverVersion GetFanMode GetFirmwareRev GetFlushBinningRows GetImageCount GetImagingStatus GetImgSequenceCount GetInfo GetInputVoltage GetInterfaceType GetIoPortAssignment GetIoPortBlankingBits GetIoPortData GetIoPortDirection GetKineticsSectionHeight GetKineticsSections GetKineticsShiftInterval GetLedAState GetLedBState GetLedMode GetMaxBinCols GetMaxBinRows GetMaxExposureTime GetMaxImgCols GetMaxImgRows GetMinExposureTime GetModel GetNumAdChannels GetNumAds GetNumOverscanCols GetPixelHeight GetPixelWidth GetPlatformType GetPreFlash GetRoiBinCol GetRoiBinRow GetRoiNumCols GetRoiNumRows GetRoiStartCol GetRoiStartRow GetSensor GetSequenceDelay GetSerialNumber GetShutterCloseDelay GetShutterState GetShutterStrobePeriod GetShutterStrobePosition GetStatus GetTdiBinningRows GetTdiCounter GetTdiRate GetTdiRows GetTempCcd GetTempHeatsink GetTotalCols GetTotalRows GetUsbFirmwareVersion GetVariableSequenceDelay IsAdSimModeOn IsBulkDownloadOn IsCCD IsColor IsConnected IsCoolerOn IsCoolingRegulated IsCoolingSupported IsFastSequenceOn IsInitialized IsInterline IsOverscanDigitized IsPostExposeFlushingDisabled IsSerialASupported IsSerialBSupported IsShutterAmpCtrlOn IsShutterForcedClosed IsShutterForcedOpen IsShutterOpen IsTriggerExternalReadoutOn IsTriggerExternalShutterOn IsTriggerNormEachOn IsTriggerNormGroupOn IsTriggerTdiKinEachOn IsTriggerTdiKinGroupOn"


#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : showconfig
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure toggles visibility of the properties window.
#
#  Arguments  :
#
 
proc showconfig { } {
 
#
#  Globals    :
#  
  if { [winfo ismapped .p] } {
     wm withdraw .p
  } else {
     wm deiconify .p
  }
}




proc setutc { {id 0} } {
global SCOPE CAMSTATUS
  set now [split [exec  date -u +%Y-%m-%d,%T.%U] ,]
  set SCOPE(obsdate) [lindex $now 0]
  set SCOPE(obstime) [lindex $now 1]
  set CAMSTATUS(Temperature) [lindex [get_temp $id] 0]
}






proc confirmaction { msg } {
   set it [ tk_dialog .d "Confirm" "$msg ?" {} -1 No "Yes"]           
   return $it
}






#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : savestate
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This routine saves the current configuration to ~/.apgui.tcl
#  from whence it will be autoloaded on subsequent runs
#
#  Arguments  :
#
#            
 
proc savestate { } {
 
#
#  Globals    :
#  
global CONFIG SCOPE ACQREGION LASTBIN OBSPARS env
   set fout [open $env(HOME)/.apgui.tcl w]
   foreach i [array names CONFIG] {
      puts $fout "catch \{set CONFIG($i) \"$CONFIG($i)\"\}"
   }
   foreach i [array names ACQREGION] {
      puts $fout "set ACQREGION($i) \"$ACQREGION($i)\""
   }
   foreach i [array names SCOPE] {
      puts $fout "set SCOPE($i) \"$SCOPE($i)\""
   }
   foreach i [array names LASTBIN] {
      puts $fout "set LASTBIN($i) \"$LASTBIN($i)\""
   }
   foreach i [array names OBSPARS] {
      puts $fout "set OBSPARS($i) \"$OBSPARS($i)\""
   }
   foreach i [array names CALS] {
      puts $fout "set CALS($i) \"$CALS($i)\""
   }
   close $fout
}






#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : toggle
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This routine opens/closes any window based upon it current open/closed status
#
#  Arguments  :
#
#               win	-	Widget id of window
 
proc toggle { win } {
 
#
#  Globals    :
#  
   if { [winfo ismapped $win] } { 
      wm withdraw $win
   } else {
      wm deiconify $win
   }
}






#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : pastelocation
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure updates the users longitude/latitude when they select
#  their location in the site list.
#
#  Arguments  :
#
 



#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : watchconfig
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure "watches" the variables in the CONFIG array. The
#  value of these variables may be altered by the user using the 
#  properties panels. This procedure ensures that the C++ instance
#  variables get updated in sync
#
#  Arguments  :
#
#               arr	-	Array name
#               var	-	tcl variable name
#               op	-	Operation specifier
 
proc watchconfig { arr var op } {
 
#
#  Globals    :
#  
#               CONFIG	-	GUI configuration
#               CAMERAS	-	Camera id's
#               CCAPI	-	Generic C++ object names
#               CCAPIW	-	C++ writable instance variables
#               CCDID	-	Camera id
#               LASTBIN	-	Last binning factor used
global CONFIG CAMERAS CCAPI CCAPIW CCDID LASTBIN APOGEEGUI ALTA
#      puts stdout "$arr $var $op"
      switch $var {
           temperature.Target { setpoint set $CONFIG($var) }
           ccd.Gain    { catch {set_gain $CONFIG(gain) $CCDID} }
      }
      foreach i [array names CCAPIW] {
         if { [string range $i 2 end] == $CCAPI($var) } {
            set camera $CAMERAS($CCDID)
            puts stdout "setting $i"
            set rebin 0
            if { $var == "geometry.BinX" } {
               set newcols [expr $CONFIG(geometry.NumCols)*$LASTBIN(x)/$CONFIG(geometry.BinX)]
               set LASTBIN(x) $CONFIG($var)
               set CONFIG(geometry.NumCols) $newcols
               set rebin 1
            }
            if { $var == "geometry.BinY" } {
               set newrows [expr $CONFIG(geometry.NumRows)*$LASTBIN(y)/$CONFIG(geometry.BinY)]
               set LASTBIN(y) $CONFIG($var)
               set CONFIG(geometry.NumRows) $newrows
               set rebin 1
            }
            if { $ALTA && ($rebin == 1)} {
               $camera SetRoiBinCol $CONFIG(geometry.BinX)
               $camera SetRoiBinRow $CONFIG(geometry.BinY)
            } else {
               $camera configure -$i $CONFIG($var)
            }
         }
      }
      if { [testgeometry] == 0 } {
         if { $APOGEEGUI } {
	         .p.props.fGeometry configure -bg orange
	 }
         bell
      } else {
	 if { $APOGEEGUI } {
	         .p.props.fGeometry configure -bg gray
	 }
      }
}




#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : watchscope
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure updates the global observation parameter defaults
#  so that they can be saved/restored as exit/startup (NYI)
#  Arguments  :
#
#               arr	-	Array name
#               var	-	tcl variable name
#               op	-	Operation specifier
 
proc watchscope { arr var op } {
 
#
#  Globals    :
#  
#               SCOPE	-	Telescope parameters, gui setup
#               OBSPARS	-	Default observation parameters
global SCOPE OBSPARS
    switch $var { 
        exptype {
                 set SCOPE(exposure)  [lindex $OBSPARS($SCOPE($var)) 0]
                 set SCOPE(numframes) [lindex $OBSPARS($SCOPE($var)) 1]
                 set SCOPE(shutter)   [lindex $OBSPARS($SCOPE($var)) 2]
                }
    }
}





#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : fanmode
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 1.0
#  Date       : Feb-21-2004
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure manages the ALTA series fan controls
#
#  Arguments  :
#
#               mode 	-	Fan mode (OFF,SLOW,MEDIUM,FAST)
#               id	-	Camera id (for multi-camera use) (optional, default is 0)
 
proc fanmode { mode {id 0} } {
 
#
#  Globals    :
#  
#               CAMERAS	-	Camera id's
#               DEBUG	-	Set to 1 for verbose logging
global CAMERAS DEBUG
    set camera $CAMERAS($id)
    set mid [lsearch "OFF SLOW MEDIUM FAST" [string toupper $mode]]
    if { $mid > -1 } {
       $camera SetFanMode $mid
       if { $DEBUG } {debuglog "ALTA Fan speed set to $mode"}
    }
}


#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : fanmode
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 1.0
#  Date       : Feb-21-2004
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure manages the ALTA series led controls
#
#  Arguments  :
#
#               mode 	-	led mode (disable,enable,nonexpose)
#		led1	- 	state for led1 illumination
#		led2	- 	state for led2 illumination
#               id	-	Camera id (for multi-camera use) (optional, default is 0)
 
proc ledmode { mode led1 led2 {id 0} } {
 
#
#  Globals    :
#  
#               CAMERAS	-	Camera id's
#               DEBUG	-	Set to 1 for verbose logging
global CAMERAS DEBUG
    set camera $CAMERAS($id)
    if { $mode > -1 } {
       $camera SetLedMode $mode
       if { $DEBUG } {debuglog "ALTA LED mode set to $mode"}
    }
    if { $led1 > -1 } {
       $camera SetLedAState $led1
       if { $DEBUG } {debuglog "ALTA LED 1 state set to $led1"}
    }
    if { $led2 > -1 } {
       $camera SetLedBState $led2
       if { $DEBUG } {debuglog "ALTA LED 2 state set to $led2"}
    }

}




#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : altamode
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 1.0
#  Date       : Feb-21-2004
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure manages the ALTA series led controls
#
#  Arguments  :
#
#               mode 	-	slow,fast
#               id	-	Camera id (for multi-camera use) (optional, default is 0)
 
proc altamode { mode {id 0} } {
 
#
#  Globals    :
#  
#               CAMERAS	-	Camera id's
#               DEBUG	-	Set to 1 for verbose logging
global CAMERAS DEBUG ALTA CONFIG
   if { $ALTA } {
    if { $CONFIG(system.Interface) == "USB" } {
      set camera $CAMERAS($id)
      if { $mode == "slow" } {
         $camera SetCcdAdcSpeed(0)
         if { $DEBUG } {debuglog "ALTA set of slow readout"}
      }
      if { $mode == "fast" } {
         $camera SetCcdAdcSpeed(1)
         if { $DEBUG } {debuglog "ALTA set of fast readout"}
      }
    }
   }
}







