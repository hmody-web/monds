<?php
declare(strict_types=1); require __DIR__.'/_bootstrap.php';ensure_storage();$w=is_file(MUNDAS_WORDS_FILE);out(['ok'=>$w,'service'=>'mundas-multiplayer','storage'=>'json+flock','time'=>now_iso(),'php'=>PHP_VERSION,'words_ready'=>$w],$w?200:500);
