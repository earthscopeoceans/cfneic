program rdGPS

! Convert one MERMAID GeoCSV track file into GPS.NR and pathNR.xy products.
!
! Build with the repository Makefile from the project root. Do not compile
! this source file directly; source order and dependencies are managed there.
!
! Normally invoked by run_cfneic with a flat GeoCSV path and station number:
!   rdGPS /path/to/float_geo_DET.csv 47
!
! Legacy directory mode remains available:
!   rdGPS FLOAT_DIR 47 [root]
!
! GPS.NR contains dive/surfacing positions, drift distances, speeds,
! accelerations, and leg angles used by cfneic location-error estimates.
! pathNR.xy contains plotting coordinates for GMT-style trajectory plots.
! Durations are days except surface drift time, which is minutes. Speeds are
! km/day, acceleration is km/day^2, and azimuth/leg angles are degrees.
!
! Return units:
! epoch2 epoch3 : Unix epoch seconds
! t23           : days
! d23           : km
! v23           : km/day
! acc           : km/day^2
! angle         : degrees
! latm2 lonm2   : degrees
! latm3 lonm3   : degrees
! ng            : count
! gdist         : m, because nint(1000*gdist)
! sdrft3        : km
! vdrft3        : km/day, because written as 86400*vdrift3
! year da time3 : timestamp fields
! surf          : surfacing count

implicit none

character*3 :: nr               ! eg 07 or 23a
character*1000 :: line,dir,fname,root
character*1000 :: method,field
character*30 :: timestamp
character*6 :: kstnm1     ! eg P0007 or P0023a (for split files)

integer :: epoch                ! Unix epoch (for debugging)
integer :: epstart
integer :: ep0,ep1              ! idem, for last leg
integer :: ep2,ep3              ! epoch at exit, entry of mixed layer
integer :: gpst1,gpstn          ! first last GPS epoch
integer :: i,j,k,n,ios,envlen,exit_code
integer :: imethod,istart,istation,ilat,ilon,ipress
integer :: largea               ! counts angles exceeding 20 deg from 180
integer :: largesd              ! counts surface drifts > 1 km
integer :: ngps                 ! nr of transmissions while at surface
integer :: nsurf                ! counts surfacings
integer :: press                ! pressure read from file
integer :: presst,lastpresst    ! epoch of pressure measurements
integer :: pressure,lastpress   ! pressure in mbar = 100*depth in m
integer :: tt(6),t3(6),year,month,day,hr,mn,sec,jday

logical :: db=.false.,ruthere,wrap=.false.
logical :: newgps=.false.       ! signals new sequence of GPS
logical :: deep                 ! true if MERMAID has seen deep layer
logical :: lastline=.false.     ! flags end of input

real*4 :: acc                   ! acceleration between GPS0-GPS2
real*4 :: angle                 ! angle between last and previous deep leg
real*4 :: az1                   ! previous deep drift azimuth
real*4 :: az2                   ! last deep drift azimuth
real*4 :: cd,c3
real*4 :: dt
real*4 :: d23                   ! distance present/last surfacing
real*4 :: d2r=0.01745329252,d2km=111.194        ! deg->rad,km
real*4 :: exdist                ! distance between gpst1 and 5.5hr trigger
real*4 :: gdist,gbaz            ! distance,azi between first, last GPS
real*4 :: glat1,glon1,glatn,glonn  ! first,last GPS position
real*4 :: lat3,lon3             ! lat, lon from GeoCSV file
real*4 :: latm0,lonm0           ! start of previous deep leg 
real*4 :: latm1,lonm1           ! end of previous deep leg 
real*4 :: latm2,lonm2           ! start of last deep leg
real*4 :: latm3,lonm3           ! end of last deep leg
real*4 :: pmx=5000.             ! pressure at bottom of mixed layer
real*4 :: sdraz1,sdraz3         ! surface drift azimuth
real*4 :: sdrift1,sdrift3       ! total drift in mixed layer and surface
real*4 :: sdrift2               ! drift between last GPS and start deep leg
real*4 :: t01,d01               ! saved t23,d23 of previous leg
real*4 :: t23                   ! duration of deep float (ep3-ep2)
real*4 :: tdrift                ! drift time at end of present leg (min)
real*4 :: v01                    ! average deep speed of previous leg
real*4 :: v23                    ! average deep speed of last leg
real*4 :: vascent,vdive         ! vertical speeds in mixed layer
real*4 :: vdrift1,vdrift3       ! speed of surface drift
real*8 :: timediff

root = '.'
exit_code = 0

n=command_argument_count()
if(n<2) then
  print *,'Usage: rdGPS geo_csv nr'
  print *,'   or: rdGPS dir nr [root]'
  print *,'e.g.: rdGPS /path/to/float_geo_DET.csv 47'
  print *,'   or: rdGPS FLOAT_DIR 47 /path/to/root'
  print *,'reads a flat GeoCSV path or root/dir/geo_DET.csv and writes GPS file'
  print *,'  GPS.47 in this directory for station P0047'
  print *,'root defaults to CFNEIC_ROOT, if set, otherwise current directory'
  stop
endif  
call get_command_argument(1,dir)
call get_command_argument(2,nr)
k=len_trim(dir)
if(k.ge.4.and.(dir(k-3:k).eq.'.csv'.or.dir(k-3:k).eq.'.CSV')) then
  fname = trim(dir)
else
  if(n>=3) then
    call get_command_argument(3,root)
  else
    call get_environment_variable('CFNEIC_ROOT',root,length=envlen,status=ios)
    if(ios.ne.0.or.envlen.le.0) root = '.'
  endif
  k=len_trim(root)
  if(k>0.and.root(k:k).ne.'/') root=trim(root)//'/'
  fname = trim(root)//trim(dir)//'/geo_DET.csv'
endif

! Open GeoCSV and map the required header fields by name
inquire(file=trim(fname), exist=ruthere)
if(ruthere) then
  print *,'Reading from:'
  print *,trim(fname)
else
  print *,'Cannot find ',trim(fname)
  call log_error('rdGPS: cannot find '//trim(fname))
  exit_code = 1
  goto 900
endif  
open(1,file=trim(fname),action='read')
do
  read(1,'(a)',iostat=ios) line
  if(is_iostat_end(ios)) then
    call log_error('rdGPS: missing geo_DET.csv header in '//trim(fname))
    exit_code = 1
    goto 900
  endif
  if(index(line,'MethodIdentifier').eq.1) exit
enddo
call csv_column(line,'MethodIdentifier',imethod)
call csv_column(line,'StartTime',istart)
call csv_column(line,'Station',istation)
call csv_column(line,'Latitude',ilat)
call csv_column(line,'Longitude',ilon)
call csv_column(line,'WaterPressure',ipress)
if(imethod.eq.0.or.istart.eq.0.or.istation.eq.0.or.ilat.eq.0.or. &
  ilon.eq.0.or.ipress.eq.0) then
  call log_error('rdGPS: missing required geo_DET.csv column in '// &
    trim(fname))
  exit_code = 1
  goto 900
endif

! Output file GPS.* has only the dive and surfacing locations
open(2,file='GPS.'//trim(nr),action='write')
write(2,'(6x,3a)') 'epoch2      epoch3   t23     d23    v23    acc', &
  '  angle    latm2    lonm2    latm3    lonm3 ng  gdist', &
  ' sdrft3 vdrft3 year da    time3              surf'
open(3,file='path'//trim(nr)//'.xy',action='write')
open(4,file='out.rdGPS'//trim(nr),action='write')
write(4,'(3a,f10.0)') 'Analysis of ',trim(fname),' pmx=',pmx
t23=0.
acc=0.
vdrift3=0.
sdrift3=0.
sdraz3=0.
latm2=0.
lonm2=0.
latm3=0.
lonm3=0.
ep3=0
gpst1=0
gpstn=0
deep=.false.
epoch=0
press=0
lastpress=0
lastpresst=0
presst=0
vascent=-1.
vdive=-1.
epstart=0
largesd=0
largea=0

if(db) write(13,*) nr

nsurf=-1        ! n counts the surfacings
ngps=0          ! counts GPS transmissiong while drifting at surface
do
  read(1,'(a)',iostat=ios) line
  if(is_iostat_end(ios)) exit

  call csv_field(line,imethod,method)
  if(index(method,'Measurement').ne.1) cycle
  call csv_field(line,istart,timestamp)
  call csv_field(line,istation,kstnm1)
  if(len_trim(kstnm1).eq.0) then
    call log_error('rdGPS: missing station in '//trim(fname)// &
      ' for GPS.'//trim(nr)//': '//trim(line))
    goto 900
  endif

  ! Is this a Pressure reading?
  if(index(method,'Measurement:Pressure').eq.1) then
    lastpress=press
    lastpresst=presst
    call csv_field(line,ipress,field)
    if(trim(field).eq.'nan') field='0'
    read(field,*,iostat=ios) press
    if(ios.ne.0) then
      write(4,'(a,i6)') 'Pressure format error, ios=',ios
      write(4,'(a)') trim(line)
      call log_error('rdGPS: pressure format error in '//trim(fname)// &
        ' for GPS.'//trim(nr)//': '//trim(line))
      exit_code = 1
      goto 900
    endif
    call stamp2epoch(timestamp,month,day,tt,presst)
    if(press<20000.and.db) write(13,'(3a,i12,2i8,i3)') 'new P line', & 
      ' date,press,ngps=',timestamp,presst,press, &
      min(999999,presst-lastpresst),ngps
    if(ngps.eq.1) then
      print *,'Warning: single GPS ignored',timestamp,press
      write(4,*) 'Warning: single GPS ignored',timestamp,press
      if(db) write(13,*) 'Break: single GPS ignored, ngps set to 0'
      lastpress=0
      lastpresst=gpstn
      ngps=0
      ep3=0             ! cause a Break
      ep2=0
    endif  

    ! first pressure reading after GPS sequence
    if(ngps>1) then     
      ! A,E,J             ! includes A:  very first dive, ot after Break
      sdraz1=sdraz3
      call del(glat1,glon1,glatn,glonn,gdist,sdraz3)
      vdrift1=vdrift3
      gdist=gdist*d2km                  ! convert degree to km
      vdrift3=gdist/(gpstn-gpst1)       ! km/s
      if(db) write(13,'(2a,i7,2f9.3,i12,i8)')'A,E,J gdist,vdrift3,', &
        'sdraz3,ep3,dt=',nint(1000*gdist),86400*vdrift3,sdraz3,ep3, &
        gpstn-gpst1
       
      ! E,J only        
      ! compute location at epoch ep3 (entry of mixed layer)
      if(deep.and.ngps>0.and.ep3>0.and.press>200) then   
        sdrift1=sdrift3
        sdrift3=vdrift3*(gpst1-ep3)        ! drift until first GPS in km
        ! find location latm3,lonm3 at ep3
        latm1=latm3
        lonm1=lonm3
        ! extrapolate back from GPS1 to find latm3,lonm3
        if(db) write(13,'(a,f9.3,a)') 'subtr sdrif3=',sdrift3,'km from gps1'
        call addrift(glat1,glon1,-sdrift3/d2km,sdraz3,latm3,lonm3)
        if(abs(sdrift3)>1.0) then 
          write(4,'(3a,f10.3)') 'Large sdrift at ',timestamp, &
          ' hrs:',(gpst1-ep3)/3600.
          write(4,'(a,2f10.3)') '  vdrft,sdrft=',86400.*vdrift3,sdrift3
          write(4,'(a,2f10.3)') '  glat1,glon1=',glat1,glon1
          largesd=largesd+1
        endif  
        az1=az2              ! last, present deep drift aziumths
        d01=d23
        call del(latm2,lonm2,latm3,lonm3,d23,az2)
        d23=d23*d2km            ! convert to km
        angle=0.
        if(ep2>0) then
          t01=t23
          t23=(ep3-ep2)/86400.    ! duration of deep float in days
          v01=v23
          v23=d23/t23               ! deep float speed km/day
          acc=0.
          if(ep0>0.and.v01>0.) acc=2*(v23-v01)/(ep2+ep3-ep0-ep1)
          if(nsurf>1) angle=az1-az2+180.
          ! make sure 0<angle<180 as in figure 3 of Paper I
          if(angle>360.) angle =angle-360.
          if(angle<0.) angle=angle+360.
          if(abs(abs(angle)-180.)>30.0) largea=largea+1
          acc=86400*acc           ! convert to km/days^2
        endif  
        if(db) then
          write(13,'(a,3f8.3,4i12)') 'acc,v23,v01,ep0-3=',acc,v23,v01,ep0, &
            ep1,ep2,ep3
          write(13,'(a,i12,6f9.3)')'E,J dt,d23,v23,az1+2,sdrft3=', & 
            ep2+ep3-ep0-ep1,d23,v23,az1,az2,sdrift3
          write(13,'(a,2i12,2f9.3)') 'writing ep2,ep3,d23,v23=', &
            ep2,ep3,d23,v23
        endif
        ! Anomalous sequence? If so cause a Break  
        if(gdist>10.0.or.t23>20.0) then
          lastpress=0
          lastpresst=gpstn
          ngps=0
          ep3=0             ! cause a Break
          ep2=0
          v23=0.
          acc=0.
          angle=0.
          if(db) write(13,*) 'Break, gdist,t23=',gdist,t23
        endif
        write(2,10) ep2,ep3,t23,d23,v23,acc,angle,latm2,lonm2,latm3,lonm3, &
          ngps,nint(1000*gdist),sdrift3,86400*vdrift3,timestamp,nsurf
        10 format(2i12,f6.1,f8.3,2f7.3,f7.1,4f9.3,i3,i7,2f7.3,1x,a,i5)
        if(nsurf>1) call wr3(lonm2,latm2,lonm3,latm3,wrap)
        deep=.false.
      else 
        lastpress=0
        lastpresst=gpstn
        if(db) write(13,'(a,2i12,2i8,1x,l1)')'E,J ignored:',ep3, &
          lastpresst,press,ngps,deep
      endif  
    endif  

    ! are we crossing the mixed layer boundary?
    ! C,G
    if(press<=pmx.and.lastpress>pmx) then       ! rising into mixed layer
      ! ep3 is start time of surface drift at end of present leg
      ep1=ep3
      dt=(pmx-lastpress)*(presst-lastpresst)/float(press-lastpress)
      ep3=lastpresst+nint(dt)           ! nint needed to avoid roundoff
      if(db) write(13,'(a,5i12,f8.0,i3)') 'C,G pressures,ep3,dt,ngps=', &
        lastpress,press,lastpresst,presst,ep3,dt,ngps
    endif  
    ! B,F,K
    if(newgps.and.press>pmx.and.lastpress<=pmx) then ! diving into deep layr
      ! ep2 is start time of deep drift
      deep=.true.
      dt=(pmx-lastpress)*(presst-lastpresst)/float(press-lastpress)
      ep0=ep2
      ep2=lastpresst+nint(dt)
      ngps=0
      sdrift2=vdrift3*(ep2-gpstn)        ! drift since gpsn to ep2
      latm0=latm2
      lonm0=lonm2
      newgps=.false.      ! .F. to flag false surfacings
      ! find position of exit mixed layer
      if(db) write(13,'(2a,4i12,2i7,i3)') 'B,F,K ep2,gpstn,presst,lastPt,',&
        'press,lastP,ngps=',ep2,gpstn,presst,lastpresst,press,lastpress, &
        ngps
      if(db) write(13,'(a,i7,a)') 'adding ',nint(1000*sdrift2),'m to gpsn'
      call addrift(glatn,glonn,sdrift2/d2km,gbaz,latm2,lonm2)
      if(db) write(13,'(a,i12,2f9.3)') 'B,F,K ep2,pos=',ep2,latm2,lonm2
    endif  
    cycle               ! read next line
  endif                          

  ! this must be a GPS line
  if(index(method,'Measurement:GPS').ne.1) then
    print *, 'Geo_DET file line not recognized:',trim(line)
    cycle
  endif  
  if(ngps.eq.0) nsurf=nsurf+1           ! count surfacings
  ngps=ngps+1
  if(ngps>1) newgps=.true.
  call csv_field(line,ilat,field)
  if(trim(field).eq.'nan') field='0'
  read(field,*,iostat=ios) lat3
  if(ios.ne.0) then
    write(4,'(a,i6)') 'GPS latitude format error, ios=',ios
    write(4,'(a)') trim(line)
    call log_error('rdGPS: GPS latitude format error in '//trim(fname)// &
      ' for GPS.'//trim(nr)//': '//trim(line))
    exit_code = 1
    goto 900
  endif
  call csv_field(line,ilon,field)
  if(trim(field).eq.'nan') field='0'
  read(field,*,iostat=ios) lon3
  if(ios.ne.0) then
    write(4,'(a,i6)') 'GPS longitude format error, ios=',ios
    write(4,'(a)') trim(line)
    call log_error('rdGPS: GPS longitude format error in '//trim(fname)// &
      ' for GPS.'//trim(nr)//': '//trim(line))
    exit_code = 1
    goto 900
  endif
  if(db) then
    call stamp2epoch(timestamp,month,day,t3,epoch)
    write(13,'(a,i3,1x,a,i12,2f9.3)') 'new GPS line ngps,date,pos=',ngps, &
      timestamp,epoch,lat3,lon3
  endif
  ! avoid dateline problem in plots by wrapping
  if(nsurf<2.and.abs(abs(lon3)-180.)<60.) wrap=.true.  

  ! D,H
  if(ngps.eq.1) then    ! if first GPS after surfacing
    call stamp2epoch(timestamp,month,day,t3,gpst1)
    if(epstart.le.0) epstart=gpst1
    gpstn=gpst1
    glat1=lat3
    glon1=lon3
    if(db) write(13,'(a,i3,i12,i5,3i3,1h:,i2.2,1h:,i2.2,2f9.3,f8.1)') &
      'D,H GPS ',ngps,gpst1,t3(1),month,day,t3(3),t3(4),t3(5),glat1,glon1,0.
    if(press>pmx) then  ! if no pressure reading < pmx
      ep1=ep3
      dt=(pmx-lastpress)*(presst-lastpresst)/float(press-lastpress)
      ep3=lastpresst+nint(dt)           ! nint needed to avoid roundoff
      if(db) write(13,'(a,5i12,f8.0)') 'Makeup press,ep3,dt=',lastpress, &
        press,lastpresst,presst,ep3,dt
      press=0.
      lastpresst=gpst1
    endif  
  else                  ! if second or later GPS after surfacing
    call stamp2epoch(timestamp,month,day,t3,gpstn)
    glatn=lat3
    glonn=lon3
    if(db) write(13,'(a,i3,i12,i5,3i3,1h:,i2.2,1h:,i2.2,2f9.3,f8.1)') &
      'nxt GPS ',ngps,gpstn,t3(1),month,day,t3(3),t3(4),t3(5),glatn,glonn, &
      (gpstn-gpst1)/60.
  endif  

enddo           ! Go back and read next line from GPS file

write(4,'(/,a,i5)') 'Number of surfacings:',nsurf
write(4,'(a,f8.1,a)') 'over ',(gpstn-epstart)/86400.,' days'
write(4,*) largesd,' surface drifts (> 1km)'
write(4,*) largea,' angles differ more than 30 deg from 180'

900 continue
if(exit_code.ne.0) stop 1
end

subroutine csv_column(header,name,idx)

implicit none

character(len=*), intent(in) :: header,name
integer, intent(out) :: idx
character*1000 :: field
integer :: col,start,pos,hlen

idx=0
col=1
start=1
hlen=len_trim(header)
do pos=1,hlen+1
  if(pos.eq.hlen+1) then
    field=' '
    if(pos.gt.start) field=adjustl(header(start:pos-1))
    if(trim(field).eq.trim(name)) idx=col
    return
  endif
  if(header(pos:pos).eq.',') then
    field=' '
    if(pos.gt.start) field=adjustl(header(start:pos-1))
    if(trim(field).eq.trim(name)) then
      idx=col
      return
    endif
    col=col+1
    start=pos+1
  endif
enddo

return
end

subroutine csv_field(line,want,value)

implicit none

character(len=*), intent(in) :: line
integer, intent(in) :: want
character(len=*), intent(out) :: value
integer :: col,start,pos,hlen

value=' '
col=1
start=1
hlen=len_trim(line)
do pos=1,hlen+1
  if(pos.eq.hlen+1) then
    if(col.eq.want.and.pos.gt.start) value=adjustl(line(start:pos-1))
    return
  endif
  if(line(pos:pos).eq.',') then
    if(col.eq.want) then
      if(pos.gt.start) value=adjustl(line(start:pos-1))
      return
    endif
    col=col+1
    start=pos+1
  endif
enddo

return
end

subroutine log_error(message)

implicit none

character(len=*), intent(in) :: message
character*300 :: logfile
integer :: ios,loglen

call get_environment_variable('CFNEIC_ERROR_LOG',logfile,length=loglen,status=ios)
if(ios.eq.0.and.loglen>0) then
  open(99,file=trim(logfile),position='append',action='write',status='unknown')
  write(99,'(a)') trim(message)
  close(99)
else
  write(6,'(a)') trim(message)
endif

return
end

subroutine wr3(lond,latd,lon3,lat3,wrap)
! write plotfile to unit 3

implicit none
real*4, intent(in) :: lond,latd,lon3,lat3
logical, intent(in) :: wrap
real*4 :: cd,c3

c3=0.
cd=0.         ! wrap longitude, only for plotting
if(wrap.and.lon3<0.) c3=360.
if(wrap.and.lond<0.) cd=360.
write(3,'(2f9.3,a)') lond+cd,latd,' i0.15'
if(abs(lon3-lond)+abs(lat3-latd).le.0.) return
write(3,'(2f9.3,a)') lon3+c3,lat3,' t0.15'

return
end

subroutine stamp2epoch(timestamp,month,day,tt,epoch)

! reads a time stamp such as 2018-06-28T00:21:26.000Z and
! puts out tt,month,day and epoch

character*30, intent(in) :: timestamp
integer, intent(out) :: epoch
integer :: tt(6),month,day
logical :: db=.false.

read(timestamp(1:4),*) tt(1)               ! year
read(timestamp(6:7),*) month               
read(timestamp(9:10),*) day
call jul(tt(1),month,day,tt(2))         ! Julian day
read(timestamp(12:13),*) tt(3)             ! hour
read(timestamp(15:16),*) tt(4)             ! minute
read(timestamp(18:19),*) tt(5)             ! sec
read(timestamp(21:23),*) tt(6)             ! millisec
call date2epoch(tt(1),tt(2),tt(3),tt(4),tt(5),epoch)

if(db) write(13,'(a,1h=,2i5,3i3,i4,1h=,i12)') timestamp,tt,epoch

return
end

subroutine addrift(lat1,lon1,d,az,lat2,lon2)

! adds drift distance d degree at azimuth angle az to (lat1,lon2)

implicit none

real*4, intent(in) :: lat1,lon1,d,az
real*4, intent(out) :: lat2,lon2
real*4 :: d2r=0.01745329252,halfpi=1.570796326795
real*8 :: clat1,clat2,rlon1,rlon2,rlat1,rlat2,rdist,raz
real*8 :: colat,latco,c,s,x
logical :: db=.false.

colat(x)=halfpi-atan(.993277*tan(x))            ! geogr-> geocent
latco(x)=atan(1.00676850*tan(halfpi-x))         ! geocent -> geograph

raz=d2r*az
rdist=d2r*d
rlat1=d2r*lat1
rlat1=colat(rlat1)
rlon1=d2r*lon1
c=cos(rlat1)*cos(rdist)+sin(rlat1)*sin(rdist)*cos(raz)
rlat2=acos(c)
s=sin(rdist)*sin(raz)/sin(rlat2)
rlon2=rlon1+asin(s)

lat2=latco(rlat2)/d2r
lon2=rlon2/d2r

if(db) write(13,'(a,6f9.3)') 'addrift ',lat1,lon1,d,az,lat2,lon2

return
end
