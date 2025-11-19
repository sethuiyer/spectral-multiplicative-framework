class SpectralVisualizer {
    constructor(canvasId) {
        this.canvas = document.getElementById(canvasId);
        this.ctx = this.canvas.getContext('2d');
        this.particles = [];
        this.width = window.innerWidth;
        this.height = window.innerHeight;
        this.canvas.width = this.width;
        this.canvas.height = this.height;

        this.initParticles(150);
        this.animate();

        window.addEventListener('resize', () => {
            this.width = window.innerWidth;
            this.height = window.innerHeight;
            this.canvas.width = this.width;
            this.canvas.height = this.height;
        });
    }

    initParticles(count) {
        for (let i = 0; i < count; i++) {
            this.particles.push({
                x: Math.random() * this.width,
                y: Math.random() * this.height,
                vx: (Math.random() - 0.5) * 2,
                vy: (Math.random() - 0.5) * 2,
                radius: Math.random() * 2 + 1,
                color: i % 2 === 0 ? '#00f2ff' : '#7000ff', // Cyan or Purple
                group: i % 2 // 0 or 1
            });
        }
    }

    draw() {
        // Semi-transparent clear for trail effect
        this.ctx.fillStyle = 'rgba(10, 10, 10, 0.1)';
        this.ctx.fillRect(0, 0, this.width, this.height);

        this.particles.forEach(p => {
            this.ctx.beginPath();
            this.ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
            this.ctx.fillStyle = p.color;
            this.ctx.fill();
        });

        // Draw connections
        this.ctx.strokeStyle = 'rgba(255, 255, 255, 0.05)';
        this.ctx.lineWidth = 0.5;

        for (let i = 0; i < this.particles.length; i++) {
            for (let j = i + 1; j < this.particles.length; j++) {
                const p1 = this.particles[i];
                const p2 = this.particles[j];
                const dx = p1.x - p2.x;
                const dy = p1.y - p2.y;
                const dist = Math.sqrt(dx * dx + dy * dy);

                if (dist < 100) {
                    // Spectral Force Logic:
                    // Same group = Attract
                    // Diff group = Repel
                    const force = (100 - dist) * 0.0005;

                    if (p1.group === p2.group) {
                        // Attract
                        p1.vx -= dx * force;
                        p1.vy -= dy * force;
                        p2.vx += dx * force;
                        p2.vy += dy * force;
                        this.ctx.strokeStyle = p1.color === '#00f2ff' ? 'rgba(0, 242, 255, 0.1)' : 'rgba(112, 0, 255, 0.1)';
                    } else {
                        // Repel
                        p1.vx += dx * force * 2; // Stronger repulsion
                        p1.vy += dy * force * 2;
                        p2.vx -= dx * force * 2;
                        p2.vy -= dy * force * 2;
                        this.ctx.strokeStyle = 'rgba(255, 50, 50, 0.05)'; // Red for conflict
                    }

                    this.ctx.beginPath();
                    this.ctx.moveTo(p1.x, p1.y);
                    this.ctx.lineTo(p2.x, p2.y);
                    this.ctx.stroke();
                }
            }
        }
    }

    update() {
        this.particles.forEach(p => {
            p.x += p.vx;
            p.y += p.vy;

            // Damping
            p.vx *= 0.99;
            p.vy *= 0.99;

            // Boundary bounce
            if (p.x < 0 || p.x > this.width) p.vx *= -1;
            if (p.y < 0 || p.y > this.height) p.vy *= -1;

            // Center gravity (keep them on screen)
            const centerX = this.width / 2;
            const centerY = this.height / 2;
            p.vx += (centerX - p.x) * 0.0001;
            p.vy += (centerY - p.y) * 0.0001;
        });
    }

    animate() {
        this.draw();
        this.update();
        requestAnimationFrame(() => this.animate());
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    // Create canvas element
    const canvas = document.createElement('canvas');
    canvas.id = 'spectral-viz';
    canvas.style.position = 'absolute';
    canvas.style.top = '0';
    canvas.style.left = '0';
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    canvas.style.zIndex = '0'; // Behind content
    canvas.style.pointerEvents = 'none';

    // Insert into hero section
    const hero = document.querySelector('.hero');
    if (hero) {
        hero.insertBefore(canvas, hero.firstChild);
        new SpectralVisualizer('spectral-viz');
    }
});
