program cfneic

! compile: gfortran -g -o $root/cfneic mod_ttak135.f90 timedel.f90 cfneic.f90
! or g7 cfneic timedel ttak135 bin

! Reads Joel's file. For dates before the last event in
! file ehb.hdf,  replaces origin time and hypocentre with
! ISC-EHB estimates. For later dates  it replaces them with the
! NEIC estimate from neic.csv
! For the ISC it reads file ehb.hdf (YEAR.hdf files from
! http://download.isc.ac.uk/isc-ehb/, concatenated). The CSV files are
! downloaded from https://earthquake.usgs.gov/earthquakes/search/ and
! concatenated in neic.csv; both files must be in chronological order.

! e.g. for SPPIM: the data from 2018 and ehh stopping at 2020:
! cat 2018.hdf 2019.hdf 2020.hdf > ehb.hdf
! cat 2021.csv 2022.csv 2023.csv > neic.csv

! For the GPS locations, run rdGPS first on Joel's geoDET.csv files
! to create files GPS.01 - GPS.54

! Output:
! The output is separate for triggered and interpolated records.
! files out.cfneic_int and out.cfneic_trig have the latest ISC or NEIC
! hypocentres, updated Mermaid location, epicentral distance gcarc and
! the observed time tobs corrected for the updated origin time.
! In addition, it has information about the geolocalization corrections
! (h and b), and in the last column the equivalent time error estimate
! locner (after squaring, variance stder and locnerr give the variance
! to be attributed to tobs).
! The input file (e.g. tomocat1.txt) is left unchanged with the original
! hypocentre, mermaid coordinates and tobs.

! file hypos_ident contains hypocentres from both ISC and NEIC that have
! origin times such that phases might arrive in the recorded seismogram
! time window, to aid in locating 'missed events'.

! Program mm2rd.f90 can be used to create raydata5 input from the output
! of cfneic.

! Input from screen, eg: cfneic tomocat.txt run1
! Outputs are detailed in cfenic_out_files.txt  
! Run this in $root


use ttak135

implicit none

type surfacing
  integer :: t2,t3
  real*4 :: d23,v23,acc,angle,latm2,lonm2,latm3,lonm3,sdrft3,vdrft3
end type surfacing

! dimension of gps is for max NF floats and max NS surfacings per float
integer, parameter :: NF=100,NS=600
type(surfacing), dimension(NS,NF) :: gps

character*8 :: kstnm
character*8 :: date
character*3 :: ok,mis
character*2 :: gpsmm(NF),kstnm2
character*80 :: dataf,fname,x
character*220 :: pde
character*300 :: emsg
character*650 :: line           ! to read one line on Joel's file
character :: ahyp*1,isol*3,iseq*2,ad*1,ident*12
integer :: ds,ios,jday,missed,ndata,nloc(NF),nmm
integer :: i,j,jb=0,k,m,n
integer :: t0,t1,t2,t3          ! mixed layer crossing epochs
integer :: tinp(6)              ! inferred origin time from input file Joel
integer :: twin(6)              ! start of seismogram time window
integer :: tisc(6)              ! Origin time from ISC or NEIC catalogue
integer :: tpick(6)             ! picked arrival time
integer :: tgps(6)              ! for printing GPS epoch
integer :: tobsep               ! epoch of phase pick
integer :: t0ep                 ! epoch of tinp
integer :: jm                   ! index of matched surfacing
integer :: day,month
integer :: mmepoch              ! epoch of seismogram record
integer :: tiscep               ! epoch of catalogue To
integer :: trtm                 ! possible travel time (for write to hypos)
integer :: epsum
integer :: kntev                ! counter of possible events (to unit 7)
real*8 :: tdif,timediff         ! used for time with millsec accuracy
real*8 :: tmax                  ! largest travel time still observable
real*4 :: v1,v2,acc,b,h,d01,d23,t23,v01,v23,gpepoch,tasc,ertot
real*4 :: stlo,stla,stel,snr,ocdp,gcarc,p,gp1epoch      ! station data
real*4 :: stlob,stlab,stloh,stlah       ! station loc after b+h correction
real*4 :: evlo1,evla1,evdp1     ! Catalogue hypocentres
real*4 :: evlo2,evla2,evdp2     ! Hypocentre stored with MM seismogram
real*4 :: Mw
real*4 :: baz,gamma,sdrft3,vdrft3
real*4 :: sec,tdrift,dist,angle
real*4 :: latm2,lonm2           ! diving location at thermocline
real*4 :: latm3,lonm3           ! ascent location at thermocline
real*4 :: tobs,stder
real*4 :: iscdepth,mb,Ms,d2km=111.194
real*4 :: phi,beta,eta          ! azimuth (N over E) of h,float,ray
real*4 :: alpha                 ! angle between two legs
logical :: db=.false.            ! debug flag
logical :: neic,ruthere,gpsok,badgps
character(len=19), external :: prtep, prtm

n=command_argument_count()
if(n<2) then
  print *,'Usage: cfneic tomocat_file ident'
  print *,'e.g. cfneic tomocat1.txt run1'
  stop
else
  call get_command_argument(1,dataf)
  call get_command_argument(2,ident)
endif

open(3,file='hypos_'//trim(ident))
write(3,'(a,35x,3a)') 'To','tobs','     evla     evlo  depth    ', &
  'Mw      dt'
open(12,file='log.cfneic_'//trim(ident))
write(12,'(a)') '  n Mermaid    nsurf'
open(10,file='out.cfneic_trig_'//trim(ident),action='write')
open(11,file='out.cfneic_int_'//trim(ident),action='write')
write(10,'(4a)') 'year  jd hr mi  s  ms     evlo     evla', &
  '  evdp   d01   d23  Mw  angle kstnm', &
  '     stlo     stla    gcarc    tobs  stder   tasc     snr  ocdp', &
  '  stel     p      v1      v2     acc       b       h locnerr'
write(11,'(4a)') 'year  jd hr mi  s  ms     evlo     evla', &
  '  evdp   d01   d23  Mw  angle kstnm', &
  '     stlo     stla    gcarc    tobs  stder   tasc     snr  ocdp', &
  '  stel     p      v1      v2     acc       b       h locnerr'

! Read neic.csv and convert it to readable neic.txt
inquire(file='neic.csv',exist=ruthere)
if(ruthere) then
  print *,'Reading neic.csv'
else
  print *,'Cannot find neic.csv'
  stop
endif

call system("awk -F, '{print $1,$2,$3,$4,$5}' neic.csv > neic.txt")
open(1,file='neic.txt',action='read')
read(1,*)               ! skip header

! Read all GPS.* files and fill array gps()
call system('ls GPS.* > dumgps')
open(8,file='dumgps',action='read')
n=0
do
  read(8,'(a)',iostat=ios) fname
  if(is_iostat_end(ios)) exit
  n=n+1
  if(n>NF) stop 'Increase NF'
  read(fname(5:6),'(a)') gpsmm(n)       ! mermaid number (2 char)
  open(9,file=fname,action='read')
  read(9,*)             ! skip header
  j=0
  badgps=.false.
  do
    read(9,*,iostat=ios) t2,t3,t23,d23,v23,acc,angle,latm2,lonm2, &
      latm3,lonm3,sdrft3,vdrft3
    if(is_iostat_end(ios)) exit
    if(ios.ne.0) then
      print *,'Reading ',fname,' t2=',t2,' j=',j
      write(6,*) 'ERROR IN GPS FILE ',ios,t2,t3
      write(emsg,'(3a,i0,a,i0)') 'cfneic: skipping bad GPS file ', &
        trim(fname),', ios=',ios,', row=',j+1
      call log_error(emsg)
      badgps=.true.
      exit
    endif
    if(t2.eq.0) cycle
    j=j+1
    if(j>NS) then
      print *,'Array limit reached reading ',trim(fname),', n=',n
      print *,'j,t2=',j,t2,' NS=',NS
      stop 'Increase NS'
    endif
    gps(j,n)%t2=t2
    gps(j,n)%t3=t3
    gps(j,n)%d23=d23
    gps(j,n)%v23=v23
    gps(j,n)%acc=acc
    gps(j,n)%angle=angle
    gps(j,n)%latm2=latm2
    gps(j,n)%lonm2=lonm2
    gps(j,n)%latm3=latm3
    gps(j,n)%lonm3=lonm3
    gps(j,n)%sdrft3=sdrft3
    gps(j,n)%vdrft3=vdrft3
    if(db) write(13,'(2i12,10f9.3)') gps(j,n)
  enddo
  close(9)
  if(badgps) then
    n=n-1
    cycle
  endif
  if (j<1) then
    call log_error('cfneic: skipping empty GPS file '//trim(fname))
    n=n-1
    cycle
  endif
  nloc(n)=j             ! number of gps locations for float n
  write(12,'(i3,1x,a8,i8)') n,gpsmm(n),nloc(n)
enddo
if(n<1) stop 'Cannot find any GPS.* files in this directory'
nmm=n  ! total number of mermaids
write(12,*) nmm,' Mermaid GPS records were input'


! open isc catalogue ehb.hdf and read first event
open(2,file='ehb.hdf',action='read')
read(2,'(a1,a3,a2,i2,2i3,1x,2i3,f6.2,a1,2f8.3,2f6.1,3f4.1)',iostat=ios)  &
  ahyp,isol,iseq,tisc(1),month,day,tisc(3),tisc(4),sec,ad, &
  evla2,evlo2,evdp2,iscdepth,mb,Ms,Mw
if(ios.ne.0) then
  write(6,*) 'Error reading first line of ehb.hdf, ios=',ios
  stop
endif
tisc(5)=sec
tisc(6)=1000*(sec-tisc(5))
if(Mw.le.0.) Mw=mb
if(Mw.le.0.) Mw=Ms
if(tisc(1)>63) then             ! year 2000 problem...
  tisc(1)=tisc(1)+1900
else
  tisc(1)=tisc(1)+2000
endif
call jul(tisc(1),month,day,tisc(2))
write(6,'(a,2i4,1x,i2,a,i2,a,f6.3)') 'File ehb.hdf starts at ', &
  tisc(1),tisc(2),tisc(3),':',tisc(4),':',sec
if(db) then
  write(13,'(7x,2a)') 'year  jd hr mi se  ms    evlo2    evla2', &
    '    evdp2        tdif'
  write(13,'(a,2i4,3i3,i4,3f9.2,f12.1)') 'ISC:  ',tisc,evlo2, &
    evla2,evdp2,tdif
endif

call date_and_time(date)

! Open Joel's file and copy the 2 header lines
open(4,file=dataf,action='read')
read(4,'(a650)') line
read(4,'(a650)') line

open(7,file='missed_events_'//trim(ident),action='write')
write(7,'(15x,a,17x,a)') 'tinp','tisc      tdif      dist'

neic=.false.                  ! Use ehb.hdf if false, else neic.txt
missed=0
kntev=0
ndata=0

! read Joel's file, compare to ISC catalogue
do
  read(4,'(a650)',iostat=ios) line
  if(db) then
    write(13,'(a)') line(1:80)
    flush(13)
  endif
  if(is_iostat_end(ios)) exit
  ndata=ndata+1
  ! get inferred To and hypocentre from line
  call gett(mmepoch,evlo1,evla1,evdp1,line)
  ! get station info and observed travel time from inferred hypocentre
  call gets(stlo,stla,stel,gcarc,ocdp,tobs,stder,snr,line)
  call date2epoch(tinp(1),tinp(2),tinp(3),tinp(4),tinp(5),t0ep)
  tobsep=epsum(t0ep,int(tobs))              ! epoch of phase pick
  read(line,*) (x,i=1,36),kstnm
  k=len_trim(kstnm)
  kstnm2=kstnm(k-1:k)
  if(db) write(13,'(a,2i4,3i3,i4,5f9.2,1x,a)') 'Joel1: ',tinp,evlo1,evla1, &
    evdp1,stlo,stla,kstnm
  tdif=timediff(tisc,tinp)          ! tdif=tinp-tisc
  ! increase catalogue time tisc until near tinp
  do while(tdif>10.)
    read(2,'(a1,a3,a2,i2,2i3,1x,2i3,f6.2,a1,2f8.3,2f6.1,3f4.1)',iostat=ios)&
      ahyp,isol,iseq,tisc(1),month,day,tisc(3),tisc(4),sec,ad, &
      evla2,evlo2,evdp2,iscdepth,mb,Ms,Mw
    if(is_iostat_end(ios)) then         ! end of ISC?
      neic=.true.
      write(6,'(a,2i4)') 'End of ISC file reached ',tisc(1),tisc(2)
      if(db) write(13,'(a)') 'End of ISC file reached, switch to NEIC'
      ! get first event from NEIC
      read(1,'(a)') pde
      read(pde,'(i4,5(1x,i2),1x,i3)') tisc(1),month,day,(tisc(i),i=3,6)
      call jul(tisc(1),month,day,tisc(2))
      read(pde,*) x,evla2,evlo2,evdp2,Mw
      tdif=timediff(tisc,tinp)      ! tinp-tisc
      tmax=timediff(tisc,twin)      ! twin-tisc
      if(tmax<1400.) then
        if(Mw.le.0.) Mw=mb
        if(Mw.le.0.) Mw=Ms
        call date2epoch(tisc(1),tisc(2),tisc(3),tisc(4),tisc(5),tiscep)
        trtm=epsum(tobsep,-tiscep)
        ok=''
        if(abs(trtm)<10) ok=' ok'
        kntev=kntev+1
        write(3,'(a19,2i11,2f9.3,f7.1,f6.1,i8,1x,2a)') prtm(tisc),tiscep, &
          tobsep,evla2,evlo2,evdp2,Mw,trtm,kstnm,ok
      endif
      call del(evla1,evlo1,evla2,evlo2,dist,baz)   ! dist to NEIC hypoc
      if(db) write(13,'(a,2i4,3i3,i4,3f9.2,f12.1)') 'NEIC: ',tisc,evlo2, &
        evla2,evdp2,tdif
      write(12,'(a,2i4,1x,i2,a,i2,a,f6.3,a)') 'From ',tisc(1),tisc(2), &
        tisc(3),':',tisc(4),':',sec,' we search NEIC'
      write(6,'(a,2i4,1x,i2,a,i2,a,f6.3,a)') 'From ',tisc(1),tisc(2), &
        tisc(3),':',tisc(4),':',sec,' we search NEIC'
      if(tdif>-10.0.and.dist<1.0) then    ! if close to ISC event
        tobs=tobs+tdif
        call matchgps
        if(gpsok) then
          call writeout
        else
          missed=missed+1
          write(7,'(2a)') line(1:76),' no usable gps match'
        endif
      else
        backspace(4)
        if(db) write(13,'(a)') 'Backspace Joel'
      endif
      exit
    else                ! regular (ISC not at the end yet)
      call jul(tisc(1),month,day,tisc(2))
      tisc(5)=sec
      tisc(6)=1000*(sec-tisc(5))
      if(tisc(1)>63) then             ! year 2000 problem...
        tisc(1)=tisc(1)+1900
      else
        tisc(1)=tisc(1)+2000
      endif
      ! bug
      if(tisc(1)>2099) then
        write(6,*) 'Bug for ndata=',ndata
        write(6,*) tisc(1),n,m,tisc(3),tisc(4),sec,ios
        stop
      endif
      if(Mw.le.0.) Mw=mb
      if(Mw.le.0.) Mw=Ms
      tdif=timediff(tisc,tinp)      ! tinp-tisc
      tmax=timediff(tisc,twin)      ! twin-tisc
      if(tmax<1400.) then
        call date2epoch(tisc(1),tisc(2),tisc(3),tisc(4),tisc(5),tiscep)
        trtm=epsum(tobsep,-tiscep)
        ok=''
        if(abs(trtm)<10) ok=' ok'
        kntev=kntev+1
        write(3,'(a19,2i11,2f9.3,f7.1,f6.1,i8,1x,2a)') prtm(tisc),tiscep, &
          tobsep,evla2,evlo2,evdp2,Mw,trtm,kstnm,ok
      endif
      if(db) write(13,'(a,2i4,3i3,i4,3f9.2,f12.1)') 'ISC:  ',tisc,evlo2, &
        evla2,evdp2,tdif
    endif
  enddo
  if(neic) exit
  call del(evla1,evlo1,evla2,evlo2,dist,baz)    ! dist to ISC hypoc
  if(db) write(13,'(a,2f9.2,a)') kstnm//' tinp<tisc of ISC, tdif, dist=', &
    tdif,dist,' deg'
  if(tdif<-10.0.or.dist>1.0) then    ! if far from ISC event
    missed=missed+1
    mis='mis'
    write(7,'(a19,2x,a19,2f10.1,1x,a)') prtm(tinp),prtm(tisc),tdif, &
      dist,kstnm
    if(db) write(13,*) 'missed event nr ',missed
    tisc=tinp           ! assume input hypocentre is the one to keep
    evla2=evla1
    evlo2=evlo1
    evdp2=evdp1
  else
    tobs=tobs+tdif
    mis=''
  endif
  call matchgps
  if(gpsok) then
    call writeout
  else
    missed=missed+1
    write(7,'(2a)') line(1:76),' last gps, no surface drift data'
  endif
enddo
! if(is_iostat_end(ios)) goto 10          ! if no need for NEIC search

! Idem, but use NEIC for the remaining ones
do
  read(4,'(a650)',iostat=ios) line
  if(db) write(13,'(a)') line(1:80)
  if(is_iostat_end(ios)) exit
  ndata=ndata+1
  ! get To and hypocentre from line
  call gett(mmepoch,evlo1,evla1,evdp1,line)
  call gets(stlo,stla,stel,gcarc,ocdp,tobs,stder,snr,line)
  call date2epoch(tinp(1),tinp(2),tinp(3),tinp(4),tinp(5),t0ep)
  tobsep=epsum(t0ep,int(tobs))              ! epoch of phase pick
!  read(line(597:601),'(a5)') kstnm
  read(line,*) (x,i=1,36),kstnm
  k=len_trim(kstnm)
  kstnm2=kstnm(k-1:k)
  if(db) write(13,'(a,2i4,3i3,i4,5f9.2,1x,a)') 'Joel2: ',tinp,evlo1,evla1, &
    evdp1,stlo,stla,kstnm
  tdif=timediff(tisc,tinp)          ! tdif=tinp-tneic
  ! increase catalogue time tisc until near tinp
  do while(tdif>10.)
    ! get next event from NEIC
    read(1,'(a)',iostat=ios) pde
    if(ios.ne.0) goto 10
    read(pde,'(i4,5(1x,i2),1x,i3)') tisc(1),month,day,(tisc(i),i=3,6)
    call jul(tisc(1),month,day,tisc(2))
    read(pde,*) x,evla2,evlo2,evdp2,Mw
    tdif=timediff(tisc,tinp)      ! tinp-tisc
    tmax=timediff(tisc,twin)      ! twin-tisc
    if(tmax<1400.) then
      if(Mw.le.0.) Mw=mb
      if(Mw.le.0.) Mw=Ms
      call date2epoch(tisc(1),tisc(2),tisc(3),tisc(4),tisc(5),tiscep)
      trtm=epsum(tobsep,-tiscep)
      ok=''
      if(abs(trtm)<10) ok=' ok'
      kntev=kntev+1
      write(3,'(a19,2i11,2f9.3,f7.1,f6.1,i8,1x,2a)') prtm(tisc),tiscep, &
        tobsep,evla2,evlo2,evdp2,Mw,trtm,kstnm,ok
    endif
    if(db) write(13,'(a,3i5,3i3.2,i4,3f9.2,f12.1)') 'NEIC,ios: ',ios, &
      tisc,evlo2,evla2,evdp2,tdif
  enddo
  call del(evla1,evlo1,evla2,evlo2,dist,baz)    ! dist to NEIC hypoc
  if(db) write(13,'(a,2f9.2)') kstnm//' hit: tinp<tNEIC, tdif, dist=', &
    tdif,dist
  if(abs(tdif)>10.0.or.dist>1.0) then    ! if too far from NEIC event
    missed=missed+1
    mis='mis'
    write(7,'(a19,2x,a19,2f10.1,1x,a)') prtm(tinp),prtm(tisc),tdif, &
      dist,kstnm
    flush(7)
    tisc=tinp           ! assume input hypocentre is the one to keep
    evla2=evla1
    evlo2=evlo1
    evdp2=evdp1
    if(db) then
      write(13,*) 'missed event nr ',missed
    endif
  else
    tobs=tobs+tdif
    mis=''
  endif
  call matchgps
  if(gpsok) then
    call writeout
  else
    missed=missed+1
    write(7,'(a)') line(1:76),' last gps, no surface drift data'
  endif
enddo

10 write(6,*) 'Last Julian date read from input file:',tinp(1),tinp(2)
write(6,*) 'Last Julian date in the NEIC file:',tisc(1),tisc(2)
write(6,*) ndata,' data were read from ',trim(dataf)
write(6,*) missed,' events could not be improved, see missed_events'
write(6,*) 'File hypos* has ',kntev,' possible events'
write(12,*) 'Last Julian date read from input file:',tinp(1),tinp(2)
write(12,*) 'Last Julian date in the NEIC file:',tisc(1),tisc(2)
write(12,*) ndata,' data were read from ',trim(dataf)
write(12,*) missed,' events could not be improved, see missed_events'
write(12,*) 'File hypos* has ',kntev,' possible events'

CONTAINS


  subroutine writeout

  ! writes results to unit 10 (triggered) or 11 (interpolated)

  real*4 :: d2r=0.01745329,e,f,r,s,x,y
  integer :: kk=0,unit
  logical :: db=.false.


  kk=kk+1
  if(db.and.kk.eq.1) write(13,'(3a)')  '     angle        d1', &
    '        d2         b         h         e         f         r', &
    '         x         y'

  unit=10
  if(tasc>10.0) unit=11
  write(unit,'(2i4,3i3.2,i4,2f9.3,3f6.1,f4.1,f7.1,1x,a5, &
    3f9.3,f8.2,2f7.2,i8,2i6,f6.3,5f8.2,f8.4,1x,a)') tisc,evlo2, &
    evla2,evdp2,d01,d23,Mw,alpha,kstnm,stloh,stlah,gcarc,tobs, &
    stder,tasc,nint(snr),nint(ocdp),nint(stel),p, &
    v01,v23,acc,b,h,ertot,trim(mis)

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
  end subroutine log_error

  subroutine matchgps

  ! find the first GPS location *after* mmepoch for Mermaid kstnm
  ! where mmepoch is the epoch of the seismogram (see gett)

  real*4 :: d2r=0.01745329,d2km=111.194,dh,da,da2,x
  real*4 :: e,f,r,y,dth,dtb
  integer :: i,j,i1,i2,k,m,hour,minut,nsec,kday,year
  logical :: db=.false.,trigger

  if(db) write(13,'(///,3a,i10,a,2i4,3i3.2,i4,2a)') 'matchgps for: ', &
    kstnm,' at ',mmepoch,' tinp=',tinp,' = ',prtm(tinp)
  gpsok=.false.

  ! find m (=mermaid number)
  m=1
  do while (m<nmm.and.kstnm2.ne.gpsmm(m))
    m=m+1
  enddo
  if(kstnm2.ne.gpsmm(m)) then
    write(6,*) 'Seeking GPS for ',kstnm2,' among:'
    write(6,'(100a3)') (gpsmm(i),i=1,nmm)
    write(emsg,'(5a)') 'cfneic: no GPS file for station ',trim(kstnm), &
      ' (',trim(kstnm2),')'
    call log_error(emsg)
    return
  endif

  if(db.and.jb.eq.0) then
    write(13,*) 'List of all surfacings for ',kstnm
    write(13,*) '  i       epoch   date'
    do i=1,nloc(m)
      write(13,'(i4,2i12,1x,a,1x,a)') i,gps(i,m)%t2,gps(i,m)%t3,  &
        prtep(gps(i,m)%t2),prtep(gps(i,m)%t3)
    enddo
  endif
  if(mmepoch>gps(nloc(m),m)%t3) then
    write(emsg,'(3a,i0,a,i0)') 'cfneic: recording after last GPS for ', &
      trim(kstnm),', mmepoch=',mmepoch,', last_t3=',gps(nloc(m),m)%t3
    call log_error(emsg)
    if(db) write(13,*) 'Last GPS skipped:',mmepoch,' > ',gps(nloc(m),m)%t3
    return
  endif

  if(db) write(13,'(a,i3,i12,/,a)') 'Bracketing Mermaid: ',m,mmepoch, &
    '  i1   i  i2    epochs'

  ! bracket jm (jm=first epoch after mmepoch)
  i1=1
  i2=nloc(m)
  if(db) write(13,'(3i4,3i12)') i1,0,i2,gps(i1,m)%t3,0,gps(i2,m)%t3
  do while(i2-i1>1)
    i=(i1+i2)/2
    if(gps(i,m)%t3<mmepoch) then
      i1=i
    else
      i2=i
    endif
    if(db) then
      call epoch2date(gps(i,m)%t3,year,kday,hour,minut,nsec)
      write(13,'(3i4,3i12,1x,2i4,i3.2,1h:,i2.2,1h:,i2.2)') i1,i,i2, &
        gps(i1,m)%t3,gps(i,m)%t3,gps(i2,m)%t3,year,kday, &
        hour,minut,nsec
    endif
  enddo
  jm=i2
  ! jm may need correction if at start of all GPS
  if(mmepoch<gps(jm,m)%t2) then
    jm=jm-1
    if(db) write(13,*) 'jm corrected:',jm,i2
    if(jm<1) then
      write(emsg,'(3a,i0,a,i0)') 'cfneic: recording before first GPS for ', &
        trim(kstnm),', mmepoch=',mmepoch,', first_t2=',gps(1,m)%t2
      call log_error(emsg)
      return
    endif
  endif
  call del(stla,stlo,gps(jm,m)%latm2,gps(jm,m)%lonm2,x,baz)     ! find x
  x=x*d2km
  if(db) then
    write(13,'(a,i5,3i12)') 'jm=',jm,gps(jm,m)%t2,mmepoch,gps(jm,m)%t3
    write(13,'(a,4f9.3)') 'station,gps:',stla,stlo,gps(jm,m)%latm2, &
      gps(jm,m)%lonm2
    write(13,'(a,i4,3f9.3)') 'dist(km) to dive ,jm,dist,d23,x=',jm,x, &
      gps(jm,m)%d23,x-0.5*gps(jm,m)%d23
    flush(13)
  endif
  x=x-0.5*gps(jm,m)%d23

  if(gps(jm,m)%t2>mmepoch.or.gps(jm,m)%t3<mmepoch) then
    write(6,'(a,2i4,3i3,i4,5f9.2,1x,a)') 'Joel: ',tinp,evlo1,evla1, &
    evdp1,stlo,stla,kstnm
    write(6,'(a,i5,3i12)') 'Error t2,mm,t3: ',jm,gps(jm,m)%t2, &
      mmepoch,gps(jm,m)%t3
    if(db) write(13,'(a,i5,i12,a,i12,a,i12)') 'Error: ',jm,gps(jm,m)%t2, &
      ' < ',mmepoch,' > ',gps(jm,m)%t3
    write(emsg,'(3a,i0,a,i0,a,i0)') 'cfneic: epoch bracket error for ', &
      trim(kstnm),', t2=',gps(jm,m)%t2,', mmepoch=',mmepoch, &
      ', t3=',gps(jm,m)%t3
    call log_error(emsg)
    return
  endif

  ! interpolated, or did this P wave trigger an ascent (<10 hr)?
  trigger=.true.
  tasc=(gps(jm,m)%t3-mmepoch)/3600.      ! ascent time in hours
  if(tasc>10.) trigger=.false.
  if(db) write(13,'(a,f6.1,1x,l1)') 'tasc (hr), trig=',tasc,trigger

  alpha=gps(jm,m)%angle
  dh=0.5*gps(jm,m)%d23
  call del(gps(jm,m)%latm2,gps(jm,m)%lonm2,gps(jm,m)%latm3, &
    gps(jm,m)%lonm3,dist,beta)  ! beta is deep drift azimuth, deg
  ! Make sure MM is in ep0-ep1 unless close to ep3 in ep2-ep3
  if(trigger.or.x>0.0.or.jm.eq.1) then
    jm=min(nloc(m),jm+1)
    if(db) write(13,'(a,i5,1x,2l2)') 'new jm=',jm,trigger,x>0.0
  else
    if(db) write(13,*) 'jm unchanged:',jm
  endif
  alpha=gps(jm,m)%angle         ! = angle with previous leg
  acc=gps(jm,m)%acc             ! = acceleration previous/current leg
  gamma=alpha-90.               ! see fig 3 in Paper I
  d23=gps(jm,m)%d23             ! see fig 4 in Paper I
  d01=gps(jm-1,m)%d23
  v23=gps(jm,m)%v23
  v01=gps(jm-1,m)%v23
  t3=gps(jm,m)%t3
  t2=gps(jm,m)%t2
  t1=gps(jm-1,m)%t3
  t0=gps(jm-1,m)%t2
  e=-0.5*d23/cos(d2r*alpha)
  f=(0.5*d01+e)*tan(d2r*gamma)
  r=sqrt(f*f+0.25*d01*d01)
  y=r*cos(asin(dh/r))
  h=r-sqrt(x*x+y*y)
  phi=atan(x/y)                 ! h angle with drift, rad
  call del(stla,stlo,evla2,evlo2,dist,eta)
  eta=eta*d2r                   ! ray angle with drift, rad
  if(mmepoch<t1) then
    b=0.5*acc*(mmepoch-t0)*(mmepoch-t1)/7.46496e9
  else
    b=0.5*acc*(mmepoch-t2)*(mmepoch-t3)/7.46496e9
  endif

  ! get corrected station coordinates for b and h offsets
  call addrift(stla,stlo,b/d2km,beta,stlab,stlob)
  if(db) write(13,'(a,4f9.3)') 'b,beta,stlab,stlob=',b,beta,stlab,stlob
  call addrift(stlab,stlob,h/d2km,beta-phi/d2r+90.,stlah,stloh)
  call del(stlah,stloh,evla2,evlo2,gcarc,baz)   ! recompute gcarc
  if(db) write(13,'(a,4f9.3)') 'h,beta-phi/d2r+90.,stlah,stloh=',h, &
    beta-phi/d2r+90.,stlah,stloh

  ! find slowness and equivalent time error
  p=slw(gcarc,evdp2)      ! slowness of P wave
  if(p<-12340.) p=0.
  p=p/6371.0              ! idem, in s/km
  beta=beta*d2r           ! drift azimuth in radians
  dth=p*h*sin(eta-beta+phi)
  dtb=p*b*cos(eta-beta)
  ertot=dth+dtb
  gpsok=.true.
  if(db) then
    write(13,'(2i4,3i3.2,i4,2f9.3)') tisc,p
    write(13,'(a,5f10.3)') 'h,b,eta,bet,ph=',h,b,eta/d2r,beta/d2r,phi/d2r
    write(13,*) 'i1,i2,jm,v,a=',i1,i2,jm,v01,v23,acc
    write(13,*) 'alpha, gamma=',alpha,gamma
    write(13,*) 'e,f,y,r=',e,f,y,r
    write(13,*) 'dh,acc,d23,d01,x,h=',dh,acc,d23,d01,x,h
    write(13,*) 'mmepoch,t0-t3=',mmepoch,t0,t1,t2,t3
    write(13,'(a,4f9.3)') 'mm&gps lat,lon: ',stla,stlo, &
      gps(jm,m)%latm3,gps(jm,m)%lonm3
    flush(13)
    jb=jb+1
  endif

  if(db.and.jb>500) stop 'debug matchgps'

  return
  end subroutine matchgps

  subroutine gett(mmepoch,evlo,evla,evdp,line)

  ! reads line and extracts To and hypocentre
  ! where To=tt=yr,jday,hr,minut,sec,msec
  ! also extracts the time (epoch) of Mermaid surfacing

  ! Compared to Joel's files:
  ! tt=SEISMOGRAM_TIME
  ! eval,evlo,evdp = EVLA,EVLO,EVDP

  implicit none

  integer, intent(out) :: mmepoch
  character*650, intent(in) :: line
  real*4, intent(out) :: evlo,evla,evdp
  integer :: jday,month,day

  ! read seismogram time and store in mmepoch
  read(line(156:159),*) twin(1)
  read(line(161:162),*) month
  read(line(164:165),*) day
  call jul(twin(1),month,day,jday)
  twin(2)=jday
  read(line(167:168),*) twin(3)
  read(line(170:171),*) twin(4)
  read(line(173:174),*) twin(5)
  twin(6)=0
  call date2epoch(twin(1),twin(2),twin(3),twin(4),twin(5),mmepoch)

  ! read inferred event origin time and coordinates
  read(line(55:58),*) tinp(1)
  read(line(60:61),*) month
  read(line(63:64),*) day
  call jul(tinp(1),month,day,jday)
  tinp(2)=jday
  read(line(66:67),*) tinp(3)
  read(line(69:70),*) tinp(4)
  read(line(72:73),*) tinp(5)
  read(line(75:76),*) tinp(6)
  tinp(6)=10*tinp(6)                ! convert 2 decimals to milliseconds
  read(line(82:93),*) evlo
  read(line(95:109),*) evla
  read(line(137:147),*) evdp
  evdp=0.001*evdp

  return
  end subroutine gett

end program cfneic


subroutine gets(stlo,stla,stel,gcarc,ocdp,tobs,stder,snr,line)

! reads line and extracts MERMAID (STation) and pick information

! Comparison with Joel's nomenclature
! stlo,stla = STLA,STLO
! stel = - STDP (elevation instead of depth, conform land stations)
! ocdp = OCDP
! gcarc = 1D_GCARC
! snr = SNR
! tobs = OBS_TRAVTIME
! stder = 2STDER / 2    (error at one-sigma level rathere than two)

implicit none

real*4, intent(out) :: stlo,stla,stel,ocdp,tobs,stder,snr,gcarc
character*650, intent(in) :: line
real*4 :: stdp

read(line(185:194),*) stlo
read(line(201:210),*) stla
read(line(214:223),*) stdp
stel=-stdp
read(line(227:236),*) ocdp
read(line(240:251),*) gcarc
read(line(319:328),*) tobs
read(line(505:514),*) stder
stder=0.5*stder              ! convert to 1-sigma level error
read(line(519:530),*) snr

return
end subroutine gets

subroutine addrift(lat1,lon1,d,az,lat2,lon2)

! adds drift distance d degree at azimuth angle az to (lat1,lon2)

implicit none

real*4, intent(in) :: lat1,lon1,d,az
real*4, intent(out) :: lat2,lon2
real*4 :: d2r=0.01745329252,halfpi=1.570796326795
real*8 :: clat1,clat2,rlon1,rlon2,rlat1,rlat2,rdist,raz
real*8 :: colat,latco,c,s,x

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

return
end

integer function epsum(ep1,ep2)
! adds ep1 and ep2 in double precision integer to avoid overflow
! if one is negative
implicit none
integer, intent(in) :: ep1,ep2
integer*8 :: ep1d,ep2d
ep1d=ep1
ep2d=ep2
epsum=ep2d+ep1d
return
end
