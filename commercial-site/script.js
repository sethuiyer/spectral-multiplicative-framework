document.addEventListener('DOMContentLoaded', () => {
    const solutionItems = document.querySelectorAll('.solution-list li');
    
    solutionItems.forEach(item => {
        item.addEventListener('click', () => {
            // Remove active class from all
            solutionItems.forEach(i => i.classList.remove('active'));
            
            // Add active class to clicked
            item.classList.add('active');
            
            // In a real implementation, this would switch the visual
            // For now, it just highlights the text
            const target = item.getAttribute('data-target');
            console.log(`Switched to ${target} view`);
        });
    });

    // Smooth scroll for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            document.querySelector(this.getAttribute('href')).scrollIntoView({
                behavior: 'smooth'
            });
        });
    });
});
