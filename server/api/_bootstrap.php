<?php
declare(strict_types=1);
require_once __DIR__ . '/_config.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: ' . MUNDAS_ALLOWED_ORIGIN);
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') { http_response_code(204); exit; }

function out(array $data, int $status = 200): never {
  http_response_code($status);
  echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
  exit;
}
function fail(string $message, int $status = 400): never { out(['ok'=>false,'error'=>$message],$status); }
function body(): array { $d=json_decode(file_get_contents('php://input') ?: '',true); return is_array($d)?$d:$_POST; }
function ulen(string $s): int { $a=preg_split('//u',$s,-1,PREG_SPLIT_NO_EMPTY); return is_array($a)?count($a):strlen($s); }
function clean_name(mixed $v): string {
  $s=trim((string)$v); $s=preg_replace('/\s+/u',' ',$s) ?? $s; $n=ulen($s);
  if($n<2||$n>18) fail('الاسم يجب أن يكون بين 2 و18 حرفاً'); return $s;
}
function clean_code(mixed $v): string { $s=strtoupper(trim((string)$v)); if(!preg_match('/^[A-Z0-9]{5}$/',$s)) fail('رمز الغرفة غير صحيح'); return $s; }
function clean_id(mixed $v): string { $s=trim((string)$v); if(!preg_match('/^[a-f0-9]{24,64}$/i',$s)) fail('معرف اللاعب غير صحيح',401); return $s; }
function random_hex(int $bytes=16): string { return bin2hex(random_bytes($bytes)); }
function token_hash(string $token): string { return hash('sha256',$token); }
function now_iso(): string { return gmdate('Y-m-d\TH:i:s\Z'); }
function room_file(string $code): string { return MUNDAS_ROOMS_DIR . '/' . $code . '.json'; }
function ensure_storage(): void { if(!is_dir(MUNDAS_ROOMS_DIR) && !mkdir(MUNDAS_ROOMS_DIR,0755,true) && !is_dir(MUNDAS_ROOMS_DIR)) fail('تعذر تجهيز التخزين',500); }

/** @return mixed */
function with_room(string $code, bool $write, callable $callback) {
  ensure_storage(); $path=room_file($code); if(!is_file($path)) fail('الغرفة غير موجودة أو انتهت',404);
  $fp=fopen($path,'c+'); if(!$fp) fail('تعذر فتح الغرفة',500);
  $lock=$write?LOCK_EX:LOCK_SH; if(!flock($fp,$lock)){fclose($fp);fail('الغرفة مشغولة، حاول ثانية',503);} rewind($fp);
  $raw=stream_get_contents($fp); $room=json_decode($raw ?: '{}',true); if(!is_array($room)||empty($room['code'])){flock($fp,LOCK_UN);fclose($fp);fail('ملف الغرفة تالف',500);}
  if((int)($room['expires_at']??0)<time()){flock($fp,LOCK_UN);fclose($fp);@unlink($path);fail('انتهت صلاحية الغرفة',404);}
  $result=$callback($room);
  if($write){
    if(is_array($result) && array_key_exists('__room',$result)){ $room=$result['__room']; $return=$result['result']??null; } else { $return=$result; }
    $room['version']=(int)($room['version']??0)+1; $room['updated_at']=time(); $room['expires_at']=time()+MUNDAS_ROOM_TTL_HOURS*3600;
    rewind($fp); ftruncate($fp,0); fwrite($fp,json_encode($room,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES)); fflush($fp);
  } else $return=$result;
  flock($fp,LOCK_UN); fclose($fp); return $return;
}
function find_player_index(array $room,string $id): int { foreach(($room['players']??[]) as $i=>$p) if(($p['id']??'')===$id) return (int)$i; return -1; }
function auth_in_room(array &$room,string $id,string $token): int {
  $i=find_player_index($room,$id); if($i<0||!hash_equals((string)$room['players'][$i]['token_hash'],token_hash($token))) fail('جلسة اللاعب غير صالحة',401);
  $room['players'][$i]['last_seen']=time(); return $i;
}
function catalog(): array { static $c=null; if(is_array($c))return $c; $raw=@file_get_contents(MUNDAS_WORDS_FILE); if($raw===false) fail('ملف الكلمات غير موجود على الخادم',500); $d=json_decode($raw,true); $c=is_array($d['categories']??null)?$d['categories']:[]; return $c; }
function public_players(array $room): array { $now=time(); return array_map(fn($p)=>['id'=>$p['id'],'name'=>$p['name'],'avatar'=>(int)$p['avatar'],'host'=>(bool)$p['is_host'],'ready'=>(bool)$p['role_seen'],'voted'=>(bool)$p['voted'],'connected'=>($now-(int)$p['last_seen'])<18],$room['players']??[]); }
function pick_round(array $selected,array $players): array {
  $valid=array_values(array_filter(catalog(),fn($c)=>in_array((string)($c['slug']??''),$selected,true)&&!empty($c['words']))); if(!$valid) fail('لا توجد كلمات للفئات المختارة',422);
  $cat=$valid[random_int(0,count($valid)-1)]; $words=array_values($cat['words']); $word=(string)$words[random_int(0,count($words)-1)]; $imp=(string)$players[random_int(0,count($players)-1)]['id'];
  return ['selected_categories'=>array_values($selected),'category_slug'=>(string)$cat['slug'],'category_name'=>(string)$cat['name_ar'],'category_emoji'=>(string)($cat['emoji']??'🎨'),'secret_word'=>$word,'imposter_id'=>$imp,'category_hint_enabled'=>true,'turn_index'=>0,'turn_order'=>array_values(array_map(fn($p)=>(string)$p['id'],$players)),'strokes'=>[],'votes'=>[],'runoff_candidate_ids'=>[],'accused_player_id'=>null,'winner'=>null,'guess_correct'=>null];
}
function normalize_ar(string $s): string { $s=strtolower(trim($s)); $s=str_replace(['أ','إ','آ','ة','ى'],['ا','ا','ا','ه','ي'],$s); return preg_replace('/[ًٌٍَُِّْـ\s]+/u','',$s) ?? $s; }
function require_host(array $p): void { if(empty($p['is_host'])) fail('هذا الإجراء للمضيف فقط',403); }
function cleanup_rooms(): int { ensure_storage(); $n=0; foreach(glob(MUNDAS_ROOMS_DIR.'/*.json')?:[] as $f){$d=json_decode(@file_get_contents($f)?:'',true); if(!is_array($d)||(int)($d['expires_at']??0)<time()){if(@unlink($f))$n++;}} return $n; }
