#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

# set GLF [file rootname [info script]]

package require PWI_Glyph 2.4

set GLF [file rootname [file tail [info script]]]

# convert radians to degrees
proc rad2deg { r } {
   set d [expr $r * 180 / 3.1415927]
   return $d
}

# Compute the warp of the given quad cell.
# Warp is the angle between normal vectors of the two triangles that
# are obtained by diagonalizing the quad.
#
# First, compute warp relative to one diagonal.
# Second, compute warp relative to other diagonal.
# Return greater of the two.
#
# (i,j+1)   (i+1,j+1)
# C---------D
# |         |
# |         |
# |         |
# A---------B
# (i,j)  (i+1,j)

proc warp { d i j } {
  set T [pw::Grid getGridPointTolerance]
  set ij [list $i $j]
  set A [$d getXYZ -grid $ij]
  set ij [list [expr $i + 1] $j]
  set B [$d getXYZ -grid $ij]
  set ij [list $i [expr $j + 1] ]
  set C [$d getXYZ -grid $ij]
  set ij [list [expr $i + 1] [expr $j + 1] ]
  set D [$d getXYZ -grid $ij]

  # diagonal CB
  # triangle ABC
  set E1 [pwu::Vector3 subtract $B $A]
  set E2 [pwu::Vector3 subtract $C $A]
  set X1 [pwu::Vector3 cross $E1 $E2]
  set L1 [pwu::Vector3 length $X1]
  # triangle DCB
  set E1 [pwu::Vector3 subtract $D $C]
  set E2 [pwu::Vector3 subtract $D $B]
  set X2 [pwu::Vector3 cross $E1 $E2]
  set L2 [pwu::Vector3 length $X2]
  if { $L1 > $T && $L2 > $T } {
    # compute angle
    set DP [pwu::Vector3 dot $X1 $X2]
    set cosTheta [expr $DP / $L1 / $L2]
    if { $cosTheta > 1 } {
      set cosTheta 1.0 
    } elseif { $cosTheta < -1 } {
      set cosTheta -1.0
    }
    set w_rad [expr acos($cosTheta) ]
    set w1_deg [rad2deg $w_rad]
  } else {
   set w1_deg 0
  }

  # diagonal AD
  # triangle BDA
  set E1 [pwu::Vector3 subtract $B $A]
  set E2 [pwu::Vector3 subtract $D $B]
  set X1 [pwu::Vector3 cross $E1 $E2]
  set L1 [pwu::Vector3 length $X1]
  # triangle CAD
  set E1 [pwu::Vector3 subtract $D $C]
  set E2 [pwu::Vector3 subtract $C $A]
  set X2 [pwu::Vector3 cross $E1 $E2]
  set L2 [pwu::Vector3 length $X2]
  if { $L1 > $T && $L2 > $T } {
    # compute angle
    set DP [pwu::Vector3 dot $X1 $X2]
    set cosTheta [expr $DP / $L1 / $L2]
    if { $cosTheta > 1 } {
      set cosTheta 1.0 
    } elseif { $cosTheta < -1 } {
      set cosTheta -1.0
    }
    set w_rad [expr acos($cosTheta) ]
    set w2_deg [rad2deg $w_rad]
  } else {
    set w2_deg 0
  }

  # return greater of the two angles
  if { $w1_deg > $w2_deg } {
    set w_deg $w1_deg 
  } else {
    set w_deg $w2_deg
  }
  return $w_deg
}

# sanity check
if { [llength [pw::Grid getAll -type pw::DomainStructured]] == 0 } {
  puts "$GLF: Aborting because there aren't any structured domains."
  exit
}

# Use domains already picked if applicable 
set mask [pw::Display createSelectionMask -requireDomain Structured]
puts $mask
pw::Display getSelectedEntities -selectionmask $mask result
if { [llength $result(Domains)] < 1 } {
  puts "Pick domain(s) for quad warp."
  if { ![pw::Display selectEntities \
           -description "Pick domain(s) for quad warp." \
           -selectionmask $mask result] } {
    exit
  }
}
# safety check
if { [llength $result(Domains)] == 0 } {
   puts "$GLF: Aborting because no domains were picked."
   exit
}

# loop through each domain, compute warp of each cell,
# track min/max warp per domain
# track min/max warp for all picked domains
puts "------------------------------------------------------"
puts "         Q U A D   C E L L S      W A R P (deg)       "
puts "------------------------------------------------------"
puts "      domain      #i      #j   Total      min      max"
puts "------------  ------  ------  ------  -------  -------"

set total_quads 0
set g_max 0.0
set g_min 360.0

foreach dom $result(Domains) {
  set dnum [string range [$dom getName] 0 11]
  set w_max 0.0
  set w_min 360.0
  set dim [$dom getDimensions]
  set Imax [lindex $dim 0]
  set Jmax [lindex $dim 1]
  for {set j 1} {$j < $Jmax} {incr j} {
    for {set i 1} {$i < $Imax} {incr i} {
      set w [warp $dom $i $j]
      if { $w < $w_min } {
        set w_min $w
      }
      if { $w > $w_max } {
        set w_max $w
      }
    }
  }

  # write data for current domain
  set n_quads [expr [expr $Imax - 1] * [expr $Jmax - 1]]
  puts [format "%12s  %6d  %6d  %6d  %7.4f  %7.4f" \
      $dnum [expr $Imax - 1] [expr $Jmax - 1] $n_quads $w_min $w_max]
  incr total_quads $n_quads
  if { $w_min < $g_min } {
    set g_min $w_min
  }
  if { $w_max > $g_max } {
    set g_max $w_max
  }
}
puts "======================================================"
puts [format "Total: %5d  %14s  %6d  %7.4f  %7.4f" \
      [llength $result(Domains)] " " $total_quads $g_min $g_max]
puts "------------------------------------------------------"

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
