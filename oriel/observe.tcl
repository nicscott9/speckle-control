
# 
# This file contains the the scripts which create the Apogee camera GUI. The procedures
# use the C++ API via a wrapper generated by SWIG.
#
#





#---------------------------------------------------------------------------
#-----------------------------------------------
#
#  Procedure  : snapshot
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure is a minimal interface to take an exposure
#
#  Arguments  :
#
#               name	-	Image file name
#               exp	-	Exposure time in seconds
#               bcorr	-	Bias correction (1=yes) (optional, default is 0)
#               shutter	-	Shutter open(1), closed(0) (optional, default is 1)
#               id	-	Camera id (for multi-camera use) (optional, default is 0)
 
proc snapshot { name exp {bcorr 0} {shutter 1} {id 0} } {
 
#
#  Globals    :
#  
#               STATUS	-	Exposure status
#               CFG	-	 
#               CAMERAS	-	Camera id's
#               DEBUG	-	Set to 1 for verbose logging
#               SCOPE	-	Telescope parameters, gui setup
global STATUS CFG CAMERAS DEBUG SCOPE ALTA
   if { $STATUS(busy) == 0 } {
    set STATUS(busy) 1
    set camera $CAMERAS($id)
    if { $ALTA } {$camera GetImagingStatus}
    $camera StartExposure $exp $shutter   
    setutc
    if { $ALTA } {$camera GetImagingStatus}
    set SCOPE(exposure) $exp
    set SCOPE(shutter) $shutter
    set SCOPE(exptype) Object
    if { $DEBUG } {debuglog "exposing (snapshot)"}
    after [expr int($exp*1000+1000)] "grabimage $name.fits $bcorr $id"
  }
}







#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : snapsleep
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure takes an exposure and then sleeps until we expect the
#  exposure is over. At which point it is read out. This routine is 
#  deprecated, as waitforimage is much more useful for normal usage.
#
#  Arguments  :
#
#               name	-	Image file name
#               exp	-	Exposure time in seconds
#               id	-	Camera id (for multi-camera use) (optional, default is 0)
#               shutter	-	Shutter open(1), closed(0) (optional, default is 1)
 
proc snapsleep { name exp {id 0} {shutter 1} } {
 
#
#  Globals    :
#  
#               STATUS	-	Exposure status
#               CAMERAS	-	Camera id's
#               SCOPE	-	Telescope parameters, gui setup
global STATUS CAMERAS SCOPE ALTA DEBUG
    set camera $CAMERAS($id)
    if { $ALTA } {$camera GetImagingStatus}
    $camera StartExposure $exp $shutter
    setutc
    if { $ALTA } {$camera GetImagingStatus}
    set SCOPE(exposure) $exp
    set SCOPE(shutter) $shutter
    if { $DEBUG } {debuglog "exposing (snapshot)"}
    set STATUS(busy) 1
    exec sleep [expr int($exp + 1)] 
    grabimage $name.fits
}




proc abortexposure { {id 0} } {
global CAMERAS ALTA STATUS
  set camera $CAMERAS($id)
  if { $ALTA } {
    $camera StopExposure 0
    $camera Reset
  } else {
    $camera write_ForceShutterOpen 0
    $camera write_Shutter 0
    $camera Flush
  }
  set STATUS(busy) 0
}


proc getaltastatus { {id 0} } {
global CAMERAS CREAD CVARS
  set c $CAMERAS($id)
  set i GetImagingStatus
#  puts stdout "[string range $i 5 end] =          [$c $i]"
  return [$c $i]
}


proc waitforalta { {n 100} {id 0} } {
global CAMERA tcl_platform
  set i 0
  while { $i < $n } {
    set r [$CAMERA GetImagingStatus]
    if { $r != 3 } {
 puts stdout "waited for $i"
       return 5
    }
    if { $tcl_platform(os) == "Darwin" } {
      exec sleep 1
    } else {
      exec usleep 1000
    }

    update idletasks
    incr i 1
  }
  return 0
}


#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : waitforimage
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure periodically wakes up and checks if the current exposure is
#  ready to be read out yet. If not, it loops around again. If the elapsed time
#  exceeds the expected exposure time (plus a couple of seconds) then it times out.
#
#  Arguments  :
#
#               exp	-	Exposure time in seconds
#               id	-	Camera id (for multi-camera use) (optional, default is 0)
 
proc waitforimage { exp {id 0} } {
 
#
#  Globals    :
#  
#               CAMERAS	-	Camera id's
#               STATUS	-	Exposure status
#               DEBUG	-	Set to 1 for verbose logging
global CAMERAS STATUS DEBUG SCOPE ALTA REMAINING tcl_platform
  set camera $CAMERAS($id)
  set REMAINING $exp
#  exec sleep 1
  if { $exp == 0 } {set exp 1}
  set STATUS(readout) 0
  set SCOPE(darktime) 0
  update idletasks
  if { $ALTA } {
    set lookfor 3
    set s 0
  } else {
    set s [$camera read_status]
    set lookfor 5
  }
  while { $s != $lookfor && $exp > 0} {
     update 
     if { $tcl_platform(os) == "Darwin" } {
       exec sleep 1
     } else {
       exec usleep 990000
     }
     update idletasks
     set exp [expr $exp -1]
     set REMAINING $exp
     if { $ALTA } {
       set s 0
     } else {
       set s [$camera read_Status]
     }
     if { $STATUS(abort) } {
        abortexposure
        set exp -1
        return -1
     }
     if { $SCOPE(darktime) > 0 } {set s 0}
     if { $DEBUG } {debuglog "waiting $exp $s"}
  }
###  if { $ALTA } {set s [waitforalta]}
  if { $SCOPE(darktime) > 0 } {
     if { $ALTA } {$camera SetShutterState 3 } else {$camera write_ForceShutterOpen 0}
     set s $lookfor
  }
  set STATUS(readout) 1
  update
  if { $s != $lookfor } {
     return 1
  }
  return 0
}






#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : obstodisk
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure performs the standard exposure operations. The image is
#  saved to a FITS file on disk.
#
#  Arguments  :
#
#               n	-	Number of frame(s)
#               id	-	Camera id (for multi-camera use) (optional, default is 0)
 
proc obstodisk { n {id 0} } {
 
#
#  Globals    :
#  
#               CAMERAS	-	Camera id's
#               STATUS	-	Exposure status
#               SCOPE	-	Telescope parameters, gui setup
#               DEBUG	-	Set to 1 for verbose logging
global CAMERAS STATUS SCOPE DEBUG ALTA REMAINING CONFIG CAMSTATUS
  set camera $CAMERAS($id)
  puts stdout "Geometry xs=$CONFIG(geometry.StartCol) ys=$CONFIG(geometry.StartRow) nx=$CONFIG(geometry.NumCols) ny=$CONFIG(geometry.NumRows)"
  puts stdout "BinX = $CONFIG(geometry.BinX) BinY = $CONFIG(geometry.BinY)"
  set CAMSTATUS(BinX) $CONFIG(geometry.BinX)
  set CAMSTATUS(BinY) $CONFIG(geometry.BinY)
  $camera SetRoiNumRows  [expr $CONFIG(geometry.NumRows)/$CONFIG(geometry.BinY)]
  $camera SetRoiNumCols  [expr $CONFIG(geometry.NumCols)/$CONFIG(geometry.BinX)]
  $camera SetRoiStartRow $CONFIG(geometry.StartRow)
  $camera SetRoiStartCol $CONFIG(geometry.StartCol)
  $camera SetRoiBinCol   $CONFIG(geometry.BinX)
  $camera SetRoiBinRow   $CONFIG(geometry.BinY)
  if { $SCOPE(comptimer) } {
    timerobstodisk $n $id
  } else {
    set camera $CAMERAS($id)
    set STATUS(busy) 1
    if { $ALTA } {$camera GetImagingStatus}
    if { [expr int($SCOPE(exposure))] > 3 } { 
       set REMAINING [expr int($SCOPE(exposure))]
       countdown [expr int($SCOPE(exposure))]
    }
    $camera StartExposure $SCOPE(exposure) $SCOPE(shutter)
    setutc
    if { $ALTA } {$camera GetImagingStatus}
    if { $DEBUG } {debuglog "exposing (obstobuffer)"}
    set timeout [waitforimage [expr int($SCOPE(exposure))] $id]
    if { $timeout == -1 } {
       puts stdout "ABORT"
    } else {   
    if { $ALTA } {
       set s -1
       while { $s != 3 } {
         set s [$camera GetImagingStatus]
         set ts [lindex "Idle Exposing ImgActive ImgReady Flushing" $s]
         puts stdout "Camera status = $ts"
         after 1000
       }
    }
      if { $DEBUG } {debuglog "Reading out..."}
      set d1 [exec date]
      $camera GetImage
      set d2 [exec date]
      puts stdout "$d1 $d2"
      countdown off
      set STATUS(readout) 0
      if { [llength [split $SCOPE(imagename) "\%"]] > 1 } {
         set name "$SCOPE(datadir)/[format "$SCOPE(imagename)" $SCOPE(seqnum)].fits"
         incr SCOPE(seqnum) 1
      } else {
         set name "$SCOPE(datadir)/$SCOPE(imagename).fits"
      }
      saveandshow tempobs $name
    }
    if { $ALTA } {
       set s -1
       $camera Reset
       after 500
       while { $s != 4 && $s != 0} {
         set s [$camera GetImagingStatus]
         set ts [lindex "Idle Exposing ImgActive ImgReady Flushing" $s]
         puts stdout "Camera status = $ts"
         if { $s == 0 } {$camera Reset}
         after 1000
       }
    }
 }
}





#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : saveandshow
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure is used to copy an image from an in-memory buffer to 
#  a FITS file on disk. It optionally deletes the file first if
#  overwrite is enabled. It also calls the appropriate routine for 
#  bias correction if that is enabled, and finally displays the image
#  in DS9 if that is enabled.
#
#  Arguments  :
#
#               buffer	-	Name of in-memory image buffer
#               name	-	Image file name
 
proc saveandshow { buffer name } {
 
#
#  Globals    :
#  
#               CAMERAS	-	Camera id's
#               STATUS	-	Exposure status
#               SCOPE	-	Telescope parameters, gui setup
#               DEBUG	-	Set to 1 for verbose logging
global CAMERAS STATUS SCOPE DEBUG
      if { [file exists $name] } {
         if { $SCOPE(overwrite) } {
            exec rm -f $name
         } else {
            set it [ tk_dialog .d "File exists" "The file named\n $name\n already exists, Overwrite it ?" {} -1 No "Yes"]           
            if { $it } {
               exec rm -f $name
            } else {
                set saveas [tk_getSaveFile -initialdir [file dirname $name] -filetypes {{{FITS images} {.fits}}}]
                set name [file rootname $saveas].fits
                saveandshow $buffer $name
                return
            }
         }
      }
      if { $SCOPE(autocalibrate) } {
          loadcalibrations
      }
      if { $SCOPE(autobias) } {
         write_cimage $buffer $SCOPE(exposure) $name
      } else {
#puts stdout "buffer = $buffer [list_buffers]"
      if { $SCOPE(autocalibrate) } {
         write_calibrated $buffer $SCOPE(exposure) $name 0
      } else {
         write16 $buffer $name
      }
#           write_image $buffer $name
      }
      if { $SCOPE(autodisplay) } {
        checkDisplay
        exec xpaset -p ds9 file $name
      } 
      set STATUS(busy) 0
}





#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : grabimage
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This routine  readouts the image from the chip, and then writes it
#  to a disk FITS file. Either raw or bias corrected images are supported.
#  
#  Arguments  :
#
#               name	-	Image file name
#               bcorr	-	Bias correction (1=yes) (optional, default is 0)
#               id	-	Camera id (for multi-camera use) (optional, default is 0)
 
proc grabimage { name {bcorr 0} {id 0} } {
 
#
#  Globals    :
#  
#               STATUS	-	Exposure status
#               CAMERAS	-	Camera id's
#               DEBUG	-	Set to 1 for verbose logging
#               SCOPE	-	Telescope parameters, gui setup
global STATUS CAMERAS DEBUG SCOPE
    set camera $CAMERAS($id)
    if { $DEBUG } {debuglog "Reading out..."}
    $camera GetImage
    if { [file exists $name] } {
      puts stdout "Overwriting $name"
      exec rm -f $name
    }
    if { $DEBUG } {debuglog "Saving to FITS $name"}
    if { $bcorr } {
       write_cimage tempobs $SCOPE(exposure) $name
    } else {
       write_image tempobs  $name
    }
    if { $SCOPE(autodisplay) } {
      checkDisplay
      exec xpaset -p ds9 file $name
    }
    set STATUS(busy) 0
}





#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : displayimage
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This routine uses the XPA interface to request a shared memory transfer
#  of image data to the DS9 image display tool.
#
#  Arguments  :
#
#               name	-	Image file name
 
proc displayimage { name } {
 
#
#  Globals    :
#  
  set pars [shmem_image $name]
  set cmd "exec xpaset -p ds9  shm array shmid [lindex $pars 0] [lindex $pars 1] \\\[xdim=[lindex $pars 2],ydim=[lindex $pars 3],bitpix=16\\\]"
  eval $cmd
}




#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : abortsequence
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure aborts the current exposure or sequence of exposures.
#  It simply sets the global abort flag and resets the GUI widgets.
#
#  Arguments  :
#
 
proc abortsequence { } {
 
#
#  Globals    :
#  
#               STATUS	-	Exposure status
global STATUS
  set STATUS(abort) 1
  countdown off
  .main.observe configure -text "Observe" -bg gray -relief raised -command startsequence
  .main.abort configure -bg gray -relief sunken -fg LightGray
  mimicMode red close
  mimicMode blue close
}





#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : continuousmode
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure continuously calls itself to repeatedly take exposures
#  and auto-display them. It will generally be used to image acquisition
#  and focus applications.
#  This mode of operation will continue until the user clicks "abort"
#
#  Arguments  :
#
#               exp	-	Exposure time in seconds
#               n	-	Number of frame(s) (optional, default is 999999)
#               id	-	Camera id (for multi-camera use) (optional, default is 0)
 
proc continuousmode { exp {n 999999} {id 0} } {
 
#
#  Globals    :
#  
#               STATUS	-	Exposure status
#               CAMERAS	-	Camera id's
global STATUS CAMERAS SCOPE ALTA
   if { $STATUS(abort) } {set STATUS(abort) 0 ; return}
   if { $STATUS(busy) } {after 100 continuousmode $exp $n}
   .main.observe configure -text "continuous" -bg green -relief sunken
   .main.abort configure -bg orange -relief raised -fg black
   update
   set camera $CAMERAS($id)
   exec rm -f /tmp/continuous.fits
   setutc
   $camera SetRoiNumRows  [expr $CONFIG(geometry.NumRows)/$CONFIG(geometry.BinY)]
   $camera SetRoiNumCols  [expr $CONFIG(geometry.NumCols)/$CONFIG(geometry.BinX)]
   $camera SetRoiStartRow $CONFIG(geometry.StartRow)
   $camera SetRoiStartCol $CONFIG(geometry.StartCol)
   $camera SetRoiBinCol   $CONFIG(geometry.BinX)
   $camera SetRoiBinRow   $CONFIG(geometry.BinY)
   if { $ALTA } {$camera GetImagingStatus}
   $camera StartExposure $exp 1
   if { $ALTA } {
       $camera GetImagingStatus
   } else {
       waitforimage $exp
   }
   $camera GetImage
   set name "$SCOPE(datadir)/[format "$SCOPE(imagename)" $SCOPE(seqnum)].fits"
   if { [file exists $name] } {
         if { $SCOPE(overwrite) } {
            exec rm -f $name
         } else {
            set it [ tk_dialog .d "File exists" "The file named\n $name\n already exists, Overwrite it ?" {} -1 No "Yes"]           
            if { $it } {
               exec rm -f $name
            } else {
                set saveas [tk_getSaveFile -initialdir [file dirname $name] -filetypes {{{FITS images} {.fits}}}]
                set name [file rootname $saveas].fits
            }
         }
   }
   incr SCOPE(seqnum) 1
   write_calibrated tempobs $SCOPE(exposure) $name 0
   checkDisplay
   exec xpaset -p ds9 file $name
###     displayimage tempobs
   incr n -1
   if { $n > 0 } {
      after 10 continuousmode $exp $n
   } else {
      .main.observe configure -text "Observe" -bg gray -relief raised
      .main.abort configure -bg gray -relief sunken -fg LightGray
   }
   set now [expr [clock clicks]/1000000.]
   puts stdout "[expr $now - $STATUS(last)] seconds since previous exposure"
   set STATUS(last) $now
}

proc continuousmode { exp {n 999999} {id 0} } {
 
#
#  Globals    :
#  
#               STATUS	-	Exposure status
#               CAMERAS	-	Camera id's
global STATUS CAMERAS SCOPE ALTA
   if { $STATUS(abort) } {set STATUS(abort) 0 ; return}
   .main.observe configure -text "continuous" -bg green -relief sunken
   .main.abort configure -bg orange -relief raised -fg black
   update
   set camera $CAMERAS($id)
   setutc
   while { $STATUS(abort) == 0 } {
      obstodisk 1 $id
   }
}


set STATUS(last) [expr [clock clicks]/1000000.]


#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : observe
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This stub routine responds to user selections on the observe menu.
#
#  Arguments  :
#
#               op	-	Operation specifier
#               id	-	Camera id (for multi-camera use) (optional, default is 0)
 
proc observe { op {id 0} } {
 
#
#  Globals    :
#  
#               SCOPE	-	Telescope parameters, gui setup
global SCOPE
  switch $op {
      region128 {acquisitionmode 128}
      region256 {acquisitionmode 256}
      region512 {acquisitionmode 512}
      manual    {acquisitionmode manual}
      multiple {continuousmode $SCOPE(exposure) 999999 $id}
      fullframe {setfullframe}
  }
}




#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : setfullframe
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This stub routine responds to user selections on the observe menu.
#
#  Arguments  :
#
#               op	-	Operation specifier
#               id	-	Camera id (for multi-camera use) (optional, default is 0)
 
proc setfullframe { } {
 
#
#  Globals    :
#  
#               SCOPE	-	Telescope parameters, gui setup
global SCOPE CONFIG LASTACQ ANDOR_DEF
   set CONFIG(geometry.BinX)      1
   set CONFIG(geometry.BinY)      1
   set CONFIG(geometry.StartCol)  1
   set CONFIG(geometry.StartRow)  1
   set CONFIG(geometry.NumCols)   [lindex [split $ANDOR_DEF(fullframe) ,] 1]
   set CONFIG(geometry.NumRows)   [lindex [split $ANDOR_DEF(fullframe) ,] 3]
   mimicMode red roi 1024x1024
   mimicMode blue roi 1024x1024
   commandAndor red "setframe fullframe"
   commandAndor blue "setframe fullframe"
   set LASTACQ fullframe
   set SCOPE(numseq) 1
   set SCOPE(numframes) 1
}






#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : acquisitionmode
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure controls the specification of a sub-image region using
#  the DS9 image display tool.
#
#  Arguments  :
#
 
proc  acquisitionmode { rdim } {
 
#
#  Globals    :
#  
#               ACQREGION	-	Sub-frame region coordinates
#               CONFIG	-	GUI configuration
global ACQREGION CONFIG LASTACQ SCOPE ANDOR_SOCKET
  puts stdout "rdim == $rdim"
  if { $rdim != "manual"} {
        commandAndor red "setframe fullframe"
        commandAndor blue "setframe fullframe"
###        positionZabers fullframe
  }
  set SCOPE(numseq) 1
  set SCOPE(numframes) 1
  if { $rdim != "manual" } {
    set LASTACQ "fullframe"
    startsequence
    after 2000
  }
  if { $rdim == "manual" } {
    catch {
      set xcenter 512
      set ycenter 512
      set ACQREGION(xs) [expr int($xcenter-$rdim/2)]
      set ACQREGION(xe) [expr int($xcenter+$rdim/2)]
      set ACQREGION(ys) [expr int($ycenter-$rdim/2)]
      set ACQREGION(ye) [expr int($ycenter+$rdim/2)]
      exec echo "box $ACQREGION(xs) $ACQREGION(ys) $ACQREGION(xe) $ACQREGION(ye) | xpaset ds9red regions
      set rdim 256
    }
    set rdim $ACQREGION(geom)
    set it [tk_dialog .d "Edit region" "Move the region in the\n image display tool then click OK" {} -1 "OK"]
    commandAndor red "forceroi $ACQREGION(xs) $ACQREGION(xe) $ACQREGION(ys) $ACQREGION(ye)"
    commandAndor blue "forceroi $ACQREGION(xs) $ACQREGION(xe) $ACQREGION(ys) $ACQREGION(ye)"
  } else {
    set resr [commandAndor red "setroi $rdim"]
    set SCOPE(red,bias) [lindex $resr 2]
    set SCOPE(red,peak) [lindex $resr 3]
    set resb [commandAndor blue "setroi $rdim"]
    set SCOPE(blue,bias) [lindex $resr 2]
    set SCOPE(blue,peak) [lindex $resr 3]
  }
  set chk [checkgain]
  mimicMode red roi [set rdim]x[set rdim]
  mimicMode blue roi [set rdim]x[set rdim]
  exec xpaset -p ds9red regions system physical
  set reg [split [exec xpaget ds9red regions] \n]
  foreach i $reg {
     if { [string range $i 0 8] == "image;box" || [string range $i 0 2] == "box" } {
        set r [lrange [split $i ",()"] 1 4]
        set ACQREGION(xs) [expr int([lindex $r 0] - [lindex $r 2]/2)]
        set ACQREGION(ys) [expr int([lindex $r 1] - [lindex $r 3]/2)]
        set ACQREGION(xe) [expr $ACQREGION(xs) + [lindex $r 2] -1]
        set ACQREGION(ye) [expr $ACQREGION(ys) + [lindex $r 3] -1]
        puts stdout "selected region $r"
     }
  }
  set CONFIG(geometry.StartCol) [expr $ACQREGION(xs)]
  set CONFIG(geometry.StartRow) [expr $ACQREGION(ys)]
  set CONFIG(geometry.NumCols) $rdim
  set CONFIG(geometry.NumRows) $rdim
  set ACQREGION(geom) $CONFIG(geometry.NumCols)
  debuglog "ROI is $ACQREGION(xs) $ACQREGION(ys) $ACQREGION(xe) $ACQREGION(ye)" 
  commandAndor red "setframe roi"
  commandAndor blue "setframe roi"
  set LASTACQ roi
  .lowlevel.rmode configure -text "Mode=speckle"
  .lowlevel.bmode configure -text "Mode=speckle"
}

proc checkgain { {table table.dat} } {
global SCOPE SPECKLE_DIR
  catch {
   set res [exec $SPECKLE_DIR/gui-scripts/autogain.py $SPECKLE_DIR/$table $SCOPE(red,bias) $SCOPE(red,peak)]
   if { [lindex [split $res \n] 6] == "Changes to EM Gain are recommended." } {
     set it [tk_dialog .d "RED CAMERA EM GAIN" $res {} -1 "OK"]
   }
   set res [exec $SPECKLE_DIR/gui-scripts/autogain.py $SPECKLE_DIR/$table $SCOPE(blue,bias) $SCOPE(blue,peak)]
   if { [lindex [split $res \n] 6] == "Changes to EM Gain are recommended." } {
     set it [tk_dialog .d "BLUE CAMERA EM GAIN" $res {} -1 "OK"]
   }
  }
}


set ACQREGION(geom) 256
set SCOPE(red,bias) 0
set SCOPE(blue,bias) 0
set SCOPE(red,peak) 1
set SCOPE(blue,peak) 1


#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : countdown
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This routine manages a countdown window. The window displays the 
#  current frame number, and seconds remaining.
#
#  Arguments  :
#
#               time	-	Countdown time in seconds
 
proc countdown { time } {
 
#
#  Globals    :
#  
#               FRAME	-	Frame number in a sequence
#               STATUS	-	Exposure status
global FRAME STATUS REMAINING
  if { $time == "off" || $STATUS(abort) } {
     wm withdraw .countdown
     return
  }
  .countdown.f configure -text $FRAME
  .countdown.t configure -text $REMAINING
  if { [winfo ismapped .countdown] == 0 } {
     wm deiconify .countdown
     wm geometry .countdown +20+20
  }
  if { $time > -1 } {
     update
     after 990 countdown $time
  } else {
     if { $STATUS(readout) } {
       .countdown.t configure -text "READING"
     } else {
       wm withdraw .countdown
     }
  }
}




#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : startsequence
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This routine manages a sequence of exposures. It updates bias columns
#  specifications in case they have been changed, then it loops thru
#  a set of frames, updating the countdown window, and calling obstodisk to 
#  do the actual exposures.
#
#  Arguments  :
#
 
proc startsequence { } {
 
#
#  Globals    :
#  
#               SCOPE	-	Telescope parameters, gui setup
#               OBSPARS	-	Default observation parameters
#               FRAME	-	Frame number in a sequence
#               STATUS	-	Exposure status
#               DEBUG	-	Set to 1 for verbose logging
global SCOPE OBSPARS FRAME STATUS DEBUG REMAINING LASTACQ TELEMETRY DATAQUAL SPECKLE_FILTER INSTRUMENT
global ANDOR_CCD ANDOR_EMCCD
 set iseqnum 0
 redisUpdate
 set SCOPE(exposureStart) [expr [clock milliseconds]/1000.0]
 .lowlevel.p configure -value 0.0
 speckleshutter red open
 speckleshutter blue open
 commandAndor red "numberkinetics $SCOPE(numframes)"
 commandAndor blue "numberkinetics $SCOPE(numframes)"
 commandAndor red "numberaccumulations $SCOPE(numaccum)"
 commandAndor blue "numberaccumulations $SCOPE(numaccum)"
 commandAndor red "programid $SCOPE(ProgID)"
 commandAndor blue "programid $SCOPE(ProgID)"
 if { $INSTRUMENT(red,emccd) } {
   commandAndor red "outputamp $ANDOR_EMCCD"
   commandAndor red "emadvanced $INSTRUMENT(red,highgain)"
   commandAndor red "emccdgain $INSTRUMENT(red,emgain)"
 } else {
   commandAndor red "outputamp $ANDOR_CCD"
 }
 if { $INSTRUMENT(blue,emccd) } {
   commandAndor blue "outputamp $ANDOR_EMCCD"
   commandAndor blue "emccdgain $INSTRUMENT(blue,emgain)"
   commandAndor blue "emadvanced $INSTRUMENT(blue,highgain)"
 } else {
   commandAndor blue "outputamp $ANDOR_CCD"
 }
 commandAndor red "dqtelemetry $DATAQUAL(rawiq) $DATAQUAL(rawcc) $DATAQUAL(rawwv) $DATAQUAL(rawbg)"
 commandAndor blue "dqtelemetry $DATAQUAL(rawiq) $DATAQUAL(rawcc) $DATAQUAL(rawwv) $DATAQUAL(rawbg)"
 commandAndor red "filter $SPECKLE_FILTER(red,current)"
 commandAndor blue "filter $SPECKLE_FILTER(blue,current)"
 set cmt [join [split [string trim [.main.comment get 0.0 end]] \n] "|"]
 commandAndor red "comments $cmt"
 commandAndor blue "comments $cmt"
 while { $iseqnum < $SCOPE(numseq) } {
  set ifrmnum 0
  while { $ifrmnum < $SCOPE(numframes) } {
   incr iseqnum 1
   incr ifrmnum 1
   set OBSPARS($SCOPE(exptype)) "$SCOPE(exposure) $SCOPE(numframes) $SCOPE(shutter)"
   set STATUS(abort) 0
   .main.observe configure -text "working" -bg green -relief sunken
   .main.abort configure -bg orange -relief raised -fg black
   wm geometry .countdown
   set i 1
   if { $SCOPE(exptype) == "Zero" || $SCOPE(exptype) == "Dark" } {
     mimicMode red close
     mimicMode blue close
   } else {
     mimicMode red open
     mimicMode blue open
   }
   commandAndor red "imagename $SCOPE(imagename)_[format %6.6d $SCOPE(seqnum)] $SCOPE(overwrite)"
   commandAndor blue "imagename $SCOPE(imagename)_[format %6.6d $SCOPE(seqnum)] $SCOPE(overwrite)"
   if { $LASTACQ == "fullframe" && $SCOPE(numframes) > 1 } {
     commandAndor red "imagename $SCOPE(imagename)_[format %6.6d $SCOPE(seqnum)]_[format %6.6d $ifrmnum] $SCOPE(overwrite)"
     commandAndor blue "imagename $SCOPE(imagename)_[format %6.6d $SCOPE(seqnum)]_[format %6.6d $ifrmnum] $SCOPE(overwrite)"
   }
   incr SCOPE(seqnum) 1
   commandAndor red "datadir $SCOPE(datadir)"
   commandAndor blue "datadir $SCOPE(datadir)"
####   flushAndors
   set redtemp  [commandAndor red gettemp]
   set bluetemp  [commandAndor blue gettemp]
   mimicMode red temp "[format %5.1f [lindex $redtemp 0]] degC"
   mimicMode blue temp "[format %5.1f [lindex $bluetemp 0]] degC"
   .main.rcamtemp configure -text "[format %5.1f [lindex $redtemp 0]] degC"
   .main.bcamtemp configure -text "[format %5.1f [lindex $bluetemp 0]] degC"
   if { $LASTACQ == "fullframe" } {
      set TELEMETRY(speckle.andor.mode) "widefield"
      acquireFrames
   } else {
      set TELEMETRY(speckle.andor.mode) "speckle"
      acquireCubes
      set ifrmnum $SCOPE(numframes)
   }
   set now [clock seconds]
   set FRAME 0
   set REMAINING 0
#   countdown [expr int($SCOPE(exposure)*$SCOPE(numframes))]
   while { $i <= $SCOPE(numframes) && $STATUS(abort) == 0 } {
      set FRAME $i
      set REMAINING [expr [clock seconds] - $now]
      if { $DEBUG} {debuglog "$SCOPE(exptype) frame $i"}
      after [expr int($SCOPE(exposure)*1000)+5]
      incr i 1
      .lowlevel.p configure -value [expr $i*100/$SCOPE(numframes)]
      update
   }
   set SCOPE(exposureEnd) [expr [clock milliseconds]/1000.0]
   .main.observe configure -text "Observe" -bg gray -relief raised
   .main.abort configure -bg gray -relief sunken -fg LightGray
   speckleshutter red close
   speckleshutter blue close
   abortsequence
  }
 }
 if { $SCOPE(autoclrcmt) } {.main.comment delete 0.0 end }
}


set SCOPE(red,bias) 0
set SCOPE(blue,bias) 0
set SCOPE(red,peak) 0
set SCOPE(blue,peak) 0



#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
#  Procedure  : timedobstodisk
#
#---------------------------------------------------------------------------
#  Author     : Dave Mills (randomfactory@gmail.com)
#  Version    : 0.9
#  Date       : Aug-01-2017
#  Copyright  : The Random Factory, Tucson AZ
#  License    : GNU GPL
#  Changes    :
#
#  This procedure performs the standard exposure operations. The image is
#  saved to a FITS file on disk.
#
#  Arguments  :
#
#               n	-	Number of frame(s)
#               id	-	Camera id (for multi-camera use) (optional, default is 0)
 
proc timerobstodisk { n {id 0} } {
 
#
#  Globals    :
#  
#               CAMERAS	-	Camera id's
#               STATUS	-	Exposure status
#               SCOPE	-	Telescope parameters, gui setup
#               DEBUG	-	Set to 1 for verbose logging
global CAMERAS STATUS SCOPE DEBUG ALTA REMAINING
    set camera $CAMERAS($id)
    set STATUS(busy) 1
#    $camera configure -m_TDI 1
    $camera StartExposure 0.02 0
    setutc
    if { $SCOPE(shutter) } {
        if { $ALTA } {$camera SetShutterState 2 } else {$camera write_ForceShutterOpen 1}
    }
    if { $DEBUG } {debuglog "exposing (obstobuffer)"}
    if { [expr int($SCOPE(exposure))] > 3 } { 
       countdown [expr int($SCOPE(exposure))]
    }
    set timer [expr [clock seconds] + $SCOPE(exposure)]
    while { [expr  $timer-[clock seconds]] > 0 } {
        exec usleep 1000
        set REMAINING [expr $timer - [clock seconds]]
        update
    }
    if { $ALTA } {$camera SetShutterState 3 } else {$camera write_ForceShutterOpen 0}
#    $camera configure -m_TDI 0
#    if { $timeout } {
#       puts stdout "TIMEOUT/ABORT"
#    } else {   
      if { $DEBUG } {debuglog "Reading out..."}
      set d1 [exec date]
      $camera GetImage
      if { $ALTA == 0 } {$camera Flush}
      set d2 [exec date]
      puts stdout "$d1 $d2"
      countdown off
      set STATUS(readout) 0
      if { [llength [split $SCOPE(imagename) "\%"]] > 1 } {
         set name "$SCOPE(datadir)/[format "$SCOPE(imagename)" $SCOPE(seqnum)].fits"
         incr SCOPE(seqnum) 1
      } else {
         set name "$SCOPE(datadir)/$SCOPE(imagename).fits"
      }
      saveandshow tempobs $name
#   }
}





