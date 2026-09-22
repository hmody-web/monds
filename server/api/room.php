<?php
declare(strict_types=1);
require __DIR__.'/_bootstrap.php';

$code=clean_code($_GET['room_code']??'');
$pid=clean_id($_GET['player_id']??'');
$token=(string)($_GET['player_token']??'');

$snapshot=with_room($code,true,function(array $room)use($pid,$token){
  auth_in_room($room,$pid,$token);
  $s=$room['state']??[];
  $phase=(string)($room['phase']??'lobby');
  $order=$s['turn_order']??[];
  $ti=(int)($s['turn_index']??0);
  $turnId=$order[$ti]??null;
  $accusedId=$s['accused_player_id']??null;
  $imposterId=$s['imposter_id']??null;

  $pub=[
    'code'=>$room['code'],
    'phase'=>$phase,
    'version'=>(int)$room['version']+1,
    'players'=>public_players($room),
    'categories'=>$s['selected_categories']??[],
    'turn_index'=>$ti,
    'turn_player_id'=>$turnId,
    'accused_player_id'=>$accusedId,
    'winner'=>$s['winner']??null,
    'category_hint_enabled'=>$s['category_hint_enabled']??true,
    'strokes'=>$s['strokes']??[],
    'runoff_candidate_ids'=>$s['runoff_candidate_ids']??[],
  ];

  // At the reveal phase the game is intentionally revealing whether the
  // accused player is the imposter. This lets every device play the same
  // suspense animation before the host continues the round.
  if($phase==='reveal' && $accusedId!==null && $imposterId!==null){
    $pub['accused_is_imposter']=$accusedId===$imposterId;
  }

  // Once the imposter has been publicly revealed (or the round is over),
  // expose their identity so all devices can show the actual player name.
  if(in_array($phase,['imposter_guess','game_over'],true) && $imposterId!==null){
    $pub['imposter_player_id']=$imposterId;
    foreach(($room['players']??[]) as $player){
      if(($player['id']??null)===$imposterId){
        $pub['imposter_name']=(string)($player['name']??'');
        break;
      }
    }
  }

  if($phase==='game_over'){
    $pub['guess_correct']=$s['guess_correct']??null;
  }

  if($phase!=='lobby'&&!empty($imposterId)){
    $isImp=$pid===$imposterId;
    $pub['my_role']=[
      'is_imposter'=>$isImp,
      'category_name'=>$s['category_name']??null,
      'category_emoji'=>$s['category_emoji']??null,
      'secret_word'=>$isImp?null:($s['secret_word']??null),
    ];
    if($phase==='game_over'){
      $pub['my_role']['secret_word']=$s['secret_word']??null;
    }
  }

  return ['__room'=>$room,'result'=>$pub];
});

out(['ok'=>true,'room'=>$snapshot]);
