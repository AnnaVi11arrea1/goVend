

addEventListener("DOMContentLoaded", () => {
    
    document.getElementById('input-box').addEventListener('keypress', function (e) {
    if (e.key === 'Enter') {
        let userMessage = e.target.value;
        e.target.value = ''; // Clear input box

        let chatBox = document.getElementById('chat-box');
        
        chatBox.innerHTML += `<p class="chat"><strong>You:</strong> ${userMessage}</p>`;
       

        let eventSource = new EventSource(`/chat?message=${encodeURIComponent(userMessage)}`);
        
        

        eventSource.onmessage = function(event) {
            console.log('Message:', event.data);
            chatBox.innerHTML += `<p class="chat"><strong>goVend:</strong> ${event.data}</p>`;
            
            chatBox.scrollTop = chatBox.scrollHeight; // Auto-scroll to the bottom
        };

        eventSource.onerror = function () {
            eventSource.close();
        };

        
    }
    });
});

