document.addEventListener('turbolinks:load', function() {
  var thumbsDownButton = document.querySelector('button.btn.btn-danger');
  var commentBox = document.getElementById('comment-box');

  thumbsDownButton.addEventListener('click', function() {
    if (commentBox.style.display === 'none' || commentBox.style.display === '') {
      commentBox.style.display = 'block';
    } else {
      commentBox.style.display = 'none';
    }
  });
});

