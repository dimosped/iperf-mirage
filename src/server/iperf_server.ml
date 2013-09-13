(*
 * Copyright (c) 2011 Richard Mortier <mort@cantab.net>
 * Copyright (c) 2012 Balraj Singh <balraj.singh@cl.cam.ac.uk>
 * Copyright (c) 2013 Dimosthenis Pediaditakis <dimosthenis.pediaditakis@cl.cam.ac.uk>
 * 
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Lwt 
open Printf
open OS.Clock
open Gc
open String

type stats = {
  mutable bytes: int64;
  mutable packets: int64;
  mutable bin_bytes:int64;
  mutable bin_packets: int64;
  mutable start_time: float;
  mutable last_time: float;
}

let port = 5001

let print_data st ts_now = 
  Printf.printf "Iperf server: t = %f, rate = %Ld KBits/s, totbytes = %Ld, live_words = %d\n%!"
    (ts_now -. st.start_time)
    (Int64.of_float (((Int64.to_float st.bin_bytes) /. (ts_now -. st.last_time)) /. 125.))
    st.bytes Gc.((stat()).live_words); 
  st.last_time <- ts_now;
  st.bin_bytes <- 0L;
  st.bin_packets <- 0L 
 
  let print_tcp_log pList = 
  try
    let (tTstampStart, _, _, _, _) = List.hd pList in
    let rec print_tcp_log_rec = function
        [] -> printf "\n---#### END OF REPORT ####---\n %!"; Lwt.return ()
      	| (tTstamp, tDelay, tOp, tKind, tArray)::body -> 
         OS.Time.sleep 0.008 >>
          lwt strArr =  Lwt.return (String.concat " " (Array.to_list (Array.map string_of_int tArray)) ) in
  	Lwt.return (printf "Time=%f, Delay=%f, Op=%s, Kind=%s, details=[%s] \n%!" (tTstamp -. tTstampStart) tDelay tOp tKind strArr ) >>
          print_tcp_log_rec body
  	in
    print_tcp_log_rec pList
  with Failure _ ->
  print_string "EMPTY HISTORY LOG!! \n%!";
  return ()

let iperf (dip,dpt) chan =
  let remoteIPAddrStr = Ipaddr.V4.to_string dip in
  printf "Iperf server: Received connection from %s:%d.\n%!" remoteIPAddrStr dpt;
  let t0 = OS.Clock.time () in
  let st = {bytes=0L; packets=0L; bin_bytes=0L; bin_packets=0L; start_time = t0; last_time = t0} in
  let rec iperf_h chan =
    match_lwt Net.Flow.read chan with
    | None ->
    	let ts_now = (OS.Clock.time ()) in 
    	st.bin_bytes <- st.bytes;
    	st.bin_packets <- st.packets;
    	st.last_time <- st.start_time;
        print_data st ts_now;
        (* Print the TCP log*)
      	(*let tcpLog = Net.Flow.getRawLogDump chan in
      	print_tcp_log (List.rev tcpLog) >>*)
        Net.Flow.close chan >>
        (printf "Iperf server: Done - closed connection (total time = %f). \n%!" (OS.Clock.time () -. t0); return ())
    | Some data -> 
      	begin
            let l = Cstruct.len data in
    		st.bytes <- (Int64.add st.bytes (Int64.of_int l));
    		iperf_h chan
    	end
  in
  (*let _ = Net.Flow.startLogging chan in*)
  iperf_h chan


let main mgr interface id =
  (*  Sleep for 3 seconds, enough time to manually start a new Xen console *)
  lwt () = OS.Time.sleep 3.0 in
  let myIPAddress = Net.Manager.get_intf_ipv4addr mgr id in
  let myIPAddressStr = Ipaddr.V4.to_string myIPAddress in
  printf "Server is using interface %s with IP address %s\n%!" (OS.Netif.string_of_id id) myIPAddressStr;
  printf "Setting up iperf server listening at port %d \n%!" port;
  printf "Done setting up server \n%!";
  Net.Flow.listen mgr (`TCPv4 ((None, port), iperf)) >>
  return ()

