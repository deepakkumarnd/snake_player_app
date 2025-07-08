import {Controller} from "@hotwired/stimulus"

export default class extends Controller {

    static targets = [
        'rows',
        'cols',
        'food',
        'head',
        'tail'
    ];

    FOOD = 3;
    HEAD = 2;
    TAIL = 1
    EMPTY = 0;

    connect() {
        console.log("Snake game loaded");
        const el = this.element;
        const data = el.dataset;
        const rows = parseInt(data.rows);
        const cols = parseInt(data.cols);

        let food_at = this.randomPosition(rows, cols);
        let head_at = this.randomPosition(rows, cols);

        while (this.arraysEqual(food_at, head_at)) {
            head_at = this.randomPosition(rows, cols);
        }

        const grid = [];
        for (let i = 0; i < rows; i++) {
            grid[i] = [];
            for (let j = 0; j < cols; j++) {
                if (this.arraysEqual([i, j], food_at)) {
                    grid[i][j] = this.FOOD;
                } else if (this.arraysEqual([i, j], head_at)) {
                    grid[i][j] = this.HEAD;
                } else {
                    grid[i][j] = this.EMPTY;
                }
            }
        }

        this.grid = grid;
        this.head_at = head_at;
        this.food_at = food_at;
        this.rows = rows;
        this.cols = cols;
        this.renderGrid("board", rows, cols);
    }

    moveLeft() {
        const left_at = [this.head_at[0], this.head_at[1] - 1]

        console.log(left_at)

        if (left_at[1] < 0) {
            console.log("Hit the left boundary");
        } else if (this.isTail(...left_at)) {
            console.log("Hit tail");
        } else if (this.isFood(...left_at)) {
            console.log("Eat food");
        } else if (this.isEmpty(...left_at)) {
            console.log("Move left ok");
            this.setCell(...this.head_at, this.EMPTY);
            this.head_at = left_at;
            this.setCell(...this.head_at, this.HEAD);
        }

        if (this.arraysEqual(this.head_at, left_at)) {
            console.log("Redraw grid");
            this.renderGrid("board", this.rows, this.cols);
        }
    }

    renderGrid(container, rows = 8, cols = 8, size = 30) {
        // Accept either an element or an element id
        const el = typeof container === 'string' ? document.getElementById(container) : container;
        if (!el) throw new Error('Container not found');

        // Clear any previous content
        el.innerHTML = '';

        // Configure CSS Grid on the container
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

    randomPosition(rows, cols) {
        return [this.randomIndex(rows), this.randomIndex(cols)];
    }

    randomIndex(limit) {
        return Math.floor(Math.random() * limit);
    }

    arraysEqual(a, b) {
        if (a.length !== b.length) return false;
        return a.every((val, i) => val === b[i]);
    }
}
