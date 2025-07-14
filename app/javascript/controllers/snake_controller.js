import {Controller} from "@hotwired/stimulus"

export default class extends Controller {

    static targets = [
        'rows',
        'cols',
        'board',
        'output'
    ];

    FOOD = 3;
    HEAD = 2;
    TAIL = 1
    EMPTY = 0;

    MOVE_LEFT = 1;
    MOVE_RIGHT = 2;
    MOVE_UP = 3;
    MOVE_DOWN = 4;

    LEFT = Object.freeze([0, -1])
    RIGHT = Object.freeze([0, 1])
    UP = Object.freeze([-1, 0])
    DOWN = Object.freeze([1, 0])
    AT_REST = Object.freeze([0, 0]);
    GAME_NEXT_MOVE_API_PATH = '/games/next-move'
    GAME_FEEDBACK_API_PATH = '/games/feedback'
    ERROR_THRESHOLD = 10;

    HIT_BOUNDARY = 'hit_wall';
    HIT_TAIL = 'hit_tail';
    EAT_FOOD = 'eat_food';
    MOVE_OK = 'move_ok';

    connect() {
        this.log("Snake game loaded");
        this.AIPlayer = false;
        this.restartGame();
    }

    startInterval() {
        this.intervalFunc = setInterval(() => {
            if (this.gameStarted) {
                this.move(this.direction);
            }

            if (this.AIPlayer) {
                this.getNextMove()
                    .then((response) => {
                        if(response.success) {
                            this.gameStarted = true;

                            if (response.direction === this.MOVE_LEFT) this.direction = this.LEFT;
                            else if (response.direction === this.MOVE_RIGHT) this.direction = this.RIGHT;
                            else if (response.direction === this.MOVE_UP) this.direction = this.UP;
                            else if (response.direction === this.MOVE_DOWN) this.direction = this.DOWN;
                            else {
                                this.errorCount += 1
                            }
                        } else {
                            this.errorCount += 1
                        }
                    }).catch((error) => console.log(`Error something went wrong ${error}`))
            }
        }, 1000)
    }

    async getNextMove() {
        const data = { grid: this.grid }
        return this.makeApiCall(this.GAME_NEXT_MOVE_API_PATH, data);
    }

    async sendFeedback(outcome) {
        const data = { grid: this.grid, outcome: outcome }
        this.makeApiCall(this.GAME_FEEDBACK_API_PATH, data)
            .then(r => {});
    }

    async makeApiCall(path, data) {
        let api_response = {};
        const csrfToken = document.querySelector('[name="csrf-token"]').content;

        try {
            const response = await fetch(path, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'X-CSRF-Token': csrfToken
                },
                body: JSON.stringify(data)
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            api_response = await response.json();
            api_response.success = true
        } catch (error) {
            this.errorCount += 1

            if (this.errorCount > this.ERROR_THRESHOLD) {
                console.log("Error threshold reached, there seems to be error in connectivity or api response. Stopping the game.")
                this.stopInterval();
            }
            console.error('Fetch error:', error.message);
            api_response = { success: false }
        }

        return api_response;
    }

    aiPlayerMode() {
        this.log("Turn on AI player mode")
        this.AIPlayer = true;
    }

    manualPlayerMode() {
        this.log("Turn off AI player mode")
        this.AIPlayer = false;
    }

    stopInterval() {
        clearInterval(this.intervalFunc)
    }

    initBoard() {
        const el = this.element;
        const data = el.dataset;
        const rows = parseInt(data.rows);
        const cols = parseInt(data.cols);

        // initialize the grid
        const grid = [];
        for (let i = 0; i < rows; i++) {
            grid[i] = [];
            for (let j = 0; j < cols; j++) {
                grid[i][j] = this.EMPTY;
            }
        }
        this.grid = grid;

        let food_at = this.randomPosition();
        this.setCell(...food_at, this.FOOD);
        let head_at = this.randomPosition();
        this.setCell(...head_at, this.HEAD);

        this.food_at = food_at;
        this.rows = rows;
        this.cols = cols;
        this.tails = [head_at];
        this.head_at = this.tails[0];
        this.renderGrid(this.boardTarget, this.rows, this.cols);
        this.log('Starting new game')
    }

    restartGame() {
        this.errorCount = 0;
        this.gameStarted = false;
        this.direction = this.AT_REST
        this.stopInterval();
        this.initBoard();
        this.startInterval();
    }

    clearOutput() {
        this.outputTarget.innerHTML = '';
    }

    move(direction) {
        this.gameStarted = true;
        this.direction = direction;

        const move_at = [this.head_at[0] + direction[0], this.head_at[1] + direction[1]]
        const bound_text = ['', 'left', 'right', 'top', 'bottom']
        const boundary = this.isBoundary(...move_at)

        if (boundary) {
            this.sendFeedback(this.HIT_BOUNDARY);
            this.log(`Hit the ${bound_text[boundary]} boundary. Game over`);
            this.restartGame();
        } else if (this.isTail(...move_at)) {
            this.sendFeedback(this.HIT_TAIL);
            this.log("Hit tail. Game over!");
            this.restartGame();
        } else if (this.isFood(...move_at)) {
            this.sendFeedback(this.EAT_FOOD);
            this.eatFood(...move_at);
            this.log("Eat food");
            this.placeFood();
        } else if (this.isEmpty(...move_at)) {
            this.sendFeedback(this.MOVE_OK)
            this.moveSnake(...move_at)
        }

        if (this.arraysEqual(this.head_at, move_at)) {
            console.log("Redraw grid");
            this.renderGrid("board", this.rows, this.cols);
        }
    }

    moveSnake(x, y) {
        this.tails.unshift([x, y]);
        const tail_cell = this.tails.pop();
        this.setCell(...tail_cell, this.EMPTY);

        for (let i = 0; i < this.tails.length; i++) {
            this.setCell(...this.tails[i], this.TAIL);
        }

        this.head_at = this.tails[0];
        this.setCell(...this.head_at, this.HEAD);
    }

    eatFood(x, y) {
        this.setCell(...this.head_at, this.TAIL);
        this.tails.unshift([x, y]);
        this.head_at = this.tails[0];
        this.setCell(...this.head_at, this.HEAD);
    }

    moveLeft() {
        this.gameStarted = true;
        this.direction = this.LEFT;
    }

    moveRight() {
        this.gameStarted = true;
        this.direction = this.RIGHT;
    }

    moveUp() {
        this.gameStarted = true;
        this.direction = this.UP;
    }

    moveDown() {
        this.gameStarted = true;
        this.direction = this.DOWN;
    }

    placeFood() {
        const food_at = this.randomPosition();
        this.setCell(...food_at, this.FOOD);
        this.food_at = food_at;

    }

    log(message) {
        const div = document.createElement('div');
        div.textContent = message
        this.outputTarget.appendChild(div);
    }

    renderGrid(container, rows = 8, cols = 8, size = 30) {
        // Accept either an element or an element id
        const el = typeof container === 'string' ? document.getElementById(container) : container;
        if (!el) throw new Error('Container not found');

        // Clear any previous content
        el.innerHTML = '';

        // Configure CSS SnakeBo on the container
        Object.assign(el.style, {
            display: 'grid',
            gridTemplateRows: `repeat(${rows}, ${size}px)`,
            gridTemplateColumns: `repeat(${cols}, ${size}px)`,
            gap: '0px',
        });

        // Create the cells
        for (let i = 0; i < rows; i++) {
            for (let j = 0; j < cols; j++) {
                const cell = document.createElement('div');
                Object.assign(cell.dataset, {target: 'cell', x: i, y: j});
                cell.className = 'cell'
                if (this.isFood(i, j)) {
                    cell.classList.add('food');
                } else if (this.isHead(i, j)) {
                    cell.classList.add('head');
                } else if (this.isTail(i, j)) {
                    cell.classList.add('tail')
                }
                el.appendChild(cell);
            }
        }
    }

    setCell(x, y, value) {
        this.grid[x][y] = value;
    }

    isHead(x, y) {
        return this.grid[x][y] === this.HEAD;
    }

    isFood(x, y) {
        return this.grid[x][y] === this.FOOD;
    }

    isTail(x, y) {
        return this.grid[x][y] === this.TAIL;
    }

    isEmpty(x, y) {
        return this.grid[x][y] === this.EMPTY;
    }

    isBoundary(x, y) {
        if (y < 0) return 1
        else if (y >= this.cols) return 2
        else if (x < 0) return 3
        else if (x >= this.rows) return 4
        else return 0
    }

    randomPosition() {
        const empty_cells = []
        this.grid.forEach((row, i) => {
            row.forEach((cell, j) => {
                if (cell === this.EMPTY) {
                    empty_cells.push([i, j]);
                }
            })
        });

        return empty_cells[this.randomIndex(empty_cells.length)];
    }

    randomIndex(limit) {
        return Math.floor(Math.random() * limit);
    }

    arraysEqual(a, b) {
        if (a.length !== b.length) return false;
        return a.every((val, i) => val === b[i]);
    }
}
