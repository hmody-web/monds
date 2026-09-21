<?php
declare(strict_types=1); require __DIR__.'/_bootstrap.php';
$d=body();$name=clean_name($d['name']??'');$avatar=max(0,min(7,(int)($d['avatar']??0)));ensure_storage();
$alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
for($try=0;$try<30;$try++){
  $code='';for($n=0;$n<5;$n++)$code.=$alphabet[random_int(0,strlen($alphabet)-1)];$path=room_file($code);$fp=@fopen($path,'x');if(!$fp)continue;
  $pid=random_hex(16);$token=random_hex(24);$now=time();$room=['code'=>$code,'host_player_id'=>$pid,'phase'=>'lobby','state'=>[],'version'=>1,'created_at'=>$now,'updated_at'=>$now,'expires_at'=>$now+MUNDAS_ROOM_TTL_HOURS*3600,'players'=>[['id'=>$pid,'token_hash'=>token_hash($token),'name'=>$name,'avatar'=>$avatar,'is_host'=>true,'role_seen'=>false,'voted'=>false,'joined_at'=>$now,'last_seen'=>$now]]];
  fwrite($fp,json_encode($room,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));fclose($fp);out(['ok'=>true,'room_code'=>$code,'player_id'=>$pid,'player_token'=>$token]);
}
fail('تعذر إنشاء الغرفة',500);
