package main

import rl "vendor:raylib"


SCREEN_WIDTH :: 560
SCREEN_HEIGHT :: 320

BALL_SPEED :: 400
BALL_RADIUS :: 6

PADDLE_SPEED :: 400
PADDLE_WIDTH :: 16
PADDLE_HEIGHT :: 64

THUD_WAV :: #load("../res/thud.wav")


Paddle :: struct {
	score:    u32,
	position: rl.Vector2,
	velocity: rl.Vector2,
}

create_paddle :: proc(position: rl.Vector2) -> Paddle {
	return Paddle{score = 0, position = position, velocity = rl.Vector2(0)}
}

constrain_paddle_position :: proc(p: ^Paddle, rect: rl.Rectangle) {
	if (rect.y <= 0) {
		p.position.y = 0
	} else if (rect.y + rect.height >= SCREEN_HEIGHT) {
		p.position.y = SCREEN_HEIGHT - rect.height
	}
}

draw_paddle :: proc(p: Paddle) {
	rl.DrawRectangleRounded(get_paddle_rect(p), 3, 6, rl.RAYWHITE)
}

get_paddle_rect :: proc(p: Paddle) -> rl.Rectangle {
	return rl.Rectangle {
		x = p.position.x,
		y = p.position.y,
		width = PADDLE_WIDTH,
		height = PADDLE_HEIGHT,
	}
}


Ball :: struct {
	position: rl.Vector2,
	velocity: rl.Vector2,
	trail:    Ball_Trail,
}

create_ball :: proc() -> Ball {
	return Ball{trail = create_ball_trail()}
}

serve_ball :: proc(b: ^Ball, direction: int) {
	b.position = rl.Vector2{SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2}
	b.velocity = rl.Vector2{f32(direction), 0} * BALL_SPEED
}

bounce_ball_off_paddle :: proc(b: ^Ball, paddle_rect: rl.Rectangle) {
	relative_y_position :=
		(b.position.y - (paddle_rect.y + paddle_rect.height / 2)) / (paddle_rect.height / 2)
	b.velocity =
		rl.Vector2Normalize(rl.Vector2{b.velocity.x > 0 ? -1 : 1, relative_y_position}) *
		PADDLE_SPEED
}

draw_ball :: proc(b: Ball) {
	draw_ball_trail(b.trail)
	rl.DrawCircleV(b.position, BALL_RADIUS, rl.WHITE)
}

get_ball_rect :: proc(b: Ball) -> rl.Rectangle {
	return rl.Rectangle {
		x = b.position.x - BALL_RADIUS,
		y = b.position.y - BALL_RADIUS,
		width = BALL_RADIUS * 2,
		height = BALL_RADIUS * 2,
	}
}


Ball_Trail :: struct {
	positions: [30]rl.Vector2,
}

create_ball_trail :: proc() -> Ball_Trail {
	return Ball_Trail{}
}

update_ball_trail :: proc(bt: ^Ball_Trail, position: rl.Vector2) {
	for i := len(bt.positions) - 1; i > 0; i -= 1 {
		bt.positions[i] = bt.positions[i - 1]
	}
	bt.positions[0] = position
}

draw_ball_trail :: proc(bt: Ball_Trail) {
	length := len(bt.positions)
	for position, i in bt.positions {
		factor := (1 - f32(i) / f32(length))
		rl.DrawCircleV(position, BALL_RADIUS * factor, rl.Fade(rl.BLUE, factor))
	}
}


Game_State :: enum {
	Pause,
	Play,
}

Game :: struct {
	state:      Game_State,
	ball:       Ball,
	p1:         Paddle,
	p2:         Paddle,
	thud_sound: rl.Sound,
}

create_game :: proc() -> Game {
	return Game {
		state = .Pause,
		ball = create_ball(),
		p1 = create_paddle(rl.Vector2{10, SCREEN_HEIGHT / 2 - PADDLE_HEIGHT / 2}),
		p2 = create_paddle(
			rl.Vector2{SCREEN_WIDTH - PADDLE_WIDTH - 10, SCREEN_HEIGHT / 2 - PADDLE_HEIGHT / 2},
		),
		thud_sound = rl.LoadSoundFromWave(
			rl.LoadWaveFromMemory(".wav", raw_data(THUD_WAV), i32(len(THUD_WAV))),
		),
	}
}

update_game :: proc(g: ^Game, delta: f32) {
	switch g.state {
	case .Pause:
		if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
			g.state = .Play
		}
	case .Play:
		if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
			g.state = .Pause
		}

		g.ball.position += g.ball.velocity * delta
		update_ball_trail(&g.ball.trail, g.ball.position)
		g.p1.velocity = rl.Vector2(0)
		g.p2.velocity = rl.Vector2(0)

		if rl.IsKeyDown(rl.KeyboardKey.W) {
			g.p1.velocity.y = -PADDLE_SPEED
		} else if rl.IsKeyDown(rl.KeyboardKey.S) {
			g.p1.velocity.y = PADDLE_SPEED
		}

		if rl.IsKeyDown(rl.KeyboardKey.UP) {
			g.p2.velocity.y = -PADDLE_SPEED
		} else if rl.IsKeyDown(rl.KeyboardKey.DOWN) {
			g.p2.velocity.y = PADDLE_SPEED
		}

		g.p1.position += g.p1.velocity * delta
		g.p2.position += g.p2.velocity * delta

		ball_rect := get_ball_rect(g.ball)
		p1_rect := get_paddle_rect(g.p1)
		p2_rect := get_paddle_rect(g.p2)

		constrain_paddle_position(&g.p1, p1_rect)
		constrain_paddle_position(&g.p2, p2_rect)

		if (ball_rect.y < 0 && g.ball.velocity.y < 0) {
			g.ball.velocity.y *= -1
		} else if (ball_rect.y + ball_rect.height > SCREEN_HEIGHT && g.ball.velocity.y > 0) {
			g.ball.velocity.y *= -1
		}

		if (ball_rect.x < 0) {
			serve_ball(&g.ball, -1)
			g.p2.score += 1
		} else if (ball_rect.x + ball_rect.width > SCREEN_WIDTH) {
			serve_ball(&g.ball, 1)
			g.p1.score += 1
		} else if (g.ball.velocity.x < 0 &&
			   g.ball.position.x < p1_rect.x + p1_rect.width &&
			   rl.CheckCollisionRecs(ball_rect, p1_rect)) {
			bounce_ball_off_paddle(&g.ball, p1_rect)
			rl.PlaySound(g.thud_sound)
		} else if (g.ball.velocity.x > 0 &&
			   g.ball.position.x < p2_rect.x &&
			   rl.CheckCollisionRecs(ball_rect, p2_rect)) {
			bounce_ball_off_paddle(&g.ball, p2_rect)
			rl.PlaySound(g.thud_sound)
		}
	}
}

draw_game :: proc(g: Game) {
	rl.DrawRectangle(10, 10, SCREEN_WIDTH - 20, SCREEN_HEIGHT - 20, rl.DARKBLUE)
	rl.DrawLineEx(
		rl.Vector2{SCREEN_WIDTH / 2, 0},
		rl.Vector2{SCREEN_WIDTH / 2, SCREEN_HEIGHT},
		2,
		rl.BLUE,
	)

	p1_score_text := rl.TextFormat("P1 %i", g.p1.score)
	rl.DrawText(p1_score_text, 20, 20, 16, rl.WHITE)

	p2_score_text := rl.TextFormat("P2 %i", g.p2.score)
	p2_score_text_width := rl.MeasureText(p2_score_text, 16)
	rl.DrawText(p2_score_text, SCREEN_WIDTH - i32(p2_score_text_width) - 20, 20, 16, rl.WHITE)

	draw_ball(g.ball)
	draw_paddle(g.p1)
	draw_paddle(g.p2)

	if g.state == .Pause {
		paused_text := cstring("Paused")
		paused_text_size := rl.MeasureTextEx(rl.GetFontDefault(), paused_text, 32, 0)

		continue_text := cstring("Press SPACE to continue")
		continue_text_size := rl.MeasureTextEx(rl.GetFontDefault(), continue_text, 16, 0)

		rl.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, rl.Fade(rl.BLACK, 0.75))
		rl.DrawText(
			paused_text,
			SCREEN_WIDTH / 2 - i32(paused_text_size.x) / 2,
			SCREEN_HEIGHT / 2 - i32(paused_text_size.y),
			32,
			rl.WHITE,
		)
		rl.DrawText(
			continue_text,
			SCREEN_WIDTH / 2 - i32(continue_text_size.x) / 2,
			SCREEN_HEIGHT / 2 - i32(continue_text_size.y) + 20,
			16,
			rl.LIGHTGRAY,
		)
	}
}


main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Pong")
	defer rl.CloseWindow()

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	rl.SetExitKey(rl.KeyboardKey.KEY_NULL)
	rl.SetTargetFPS(60)

	game := create_game()
	serve_ball(&game.ball, 1)

	for !rl.WindowShouldClose() {
		delta: f32 = rl.GetFrameTime()
		update_game(&game, delta)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLUE)
		draw_game(game)
		rl.EndDrawing()
	}
}
