local M = {}

function M.new()
  return {
    front = 1,
    rear = 0,
    data = {}
  }
end

function M.enqueue(queue, item)
  queue.rear = queue.rear + 1
  queue.data[queue.rear] = item
end

function M.dequeue(queue)
  if queue.rear >= queue.front then
    local item = queue.data[queue.front]
    queue.front = queue.front + 1
    return item
  else
    error("Queue is empty")
  end
end

function M.is_empty(queue)
  return queue.front > queue.rear
end

return M
