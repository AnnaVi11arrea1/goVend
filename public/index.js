addEventListener("DOMContentLoaded", (event) => {
    document.getElementById('input-box').addEventListener('keypress', function (e) {
    if (e.key === 'Enter') {
        let userMessage = e.target.value;
        e.target.value = ''; // Clear input box

        let chatBox = document.getElementById('chat-box');
        chatBox.innerHTML += `<p><strong>You:</strong> ${userMessage}</p>`;

        let eventSource = new EventSource('/app.rb');
        
        

        eventSource.onmessage = function(event) {
            console.log('Message:', message);
            chatBox.innerHTML += `<p><strong>GPT-3.5 Turbo:</strong> ${event.data}</p>`;
            chatBox.scrollTop = chatBox.scrollHeight; // Auto-scroll to the bottom
        };

        eventSource.onerror = function () {
            eventSource.close();
        };
    }
    });
});
