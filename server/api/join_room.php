<?php
declare(strict_types=1); require __DIR__.'/_bootstrap.php';
$d=body();$code=clean_code($d['room_code']??'');$name=clean_name($d['name']??'');$avatar=max(0,min(7,(int)($d['avatar']??0)));$pid=random_hex(16);$token=random_hex(24);
with_room($code,true,function(array $room)use($name,$avatar,$pid,$token){
  if(($room['phase']??'')!=='lobby')fail('بدأت اللعبة بالفعل',409);if(count($room['players']??[])>=MUNDAS_MAX_PLAYERS)fail('الغرفة ممتلئة',409);
  foreach($room['players'] as $p)if(trim((string)$p['name'])===$name)fail('هذا الاسم مستخدم في الغرفة');$now=time();
  $room['players'][]=['id'=>$pid,'token_hash'=>token_hash($token),'name'=>$name,'avatar'=>$avatar,'is_host'=>false,'role_seen'=>false,'voted'=>false,'joined_at'=>$now,'last_seen'=>$now];return ['__room'=>$room];
});
out(['ok'=>true,'room_code'=>$code,'player_id'=>$pid,'player_token'=>$token]);
