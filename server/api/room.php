<?php
declare(strict_types=1); require __DIR__.'/_bootstrap.php';
$code=clean_code($_GET['room_code']??'');$pid=clean_id($_GET['player_id']??'');$token=(string)($_GET['player_token']??'');
$snapshot=with_room($code,true,function(array $room)use($pid,$token){
  auth_in_room($room,$pid,$token);$s=$room['state']??[];$order=$s['turn_order']??[];$ti=(int)($s['turn_index']??0);$turnId=$order[$ti]??null;
  $pub=['code'=>$room['code'],'phase'=>$room['phase'],'version'=>(int)$room['version']+1,'players'=>public_players($room),'categories'=>$s['selected_categories']??[],'turn_index'=>$ti,'turn_player_id'=>$turnId,'accused_player_id'=>$s['accused_player_id']??null,'winner'=>$s['winner']??null,'category_hint_enabled'=>$s['category_hint_enabled']??true,'strokes'=>$s['strokes']??[],'runoff_candidate_ids'=>$s['runoff_candidate_ids']??[]];
  if(($room['phase']??'lobby')!=='lobby'&&!empty($s['imposter_id'])){$isImp=$pid===$s['imposter_id'];$pub['my_role']=['is_imposter'=>$isImp,'category_name'=>$s['category_name']??null,'category_emoji'=>$s['category_emoji']??null,'secret_word'=>$isImp?null:($s['secret_word']??null)];if($room['phase']==='game_over')$pub['my_role']['secret_word']=$s['secret_word']??null;}
  return ['__room'=>$room,'result'=>$pub];
});
out(['ok'=>true,'room'=>$snapshot]);
