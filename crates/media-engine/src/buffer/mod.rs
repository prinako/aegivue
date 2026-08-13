use std::{collections::VecDeque, time::Duration};

#[derive(Debug)]
pub struct Packet<T> {
    pub timestamp: Duration,
    pub value: T,
}
#[derive(Debug)]
pub struct PacketBuffer<T> {
    window: Duration,
    packets: VecDeque<Packet<T>>,
}
impl<T> PacketBuffer<T> {
    pub fn new(window: Duration) -> Self {
        Self {
            window,
            packets: VecDeque::new(),
        }
    }
    pub fn push(&mut self, packet: Packet<T>) {
        let cutoff = packet.timestamp.saturating_sub(self.window);
        while self.packets.front().is_some_and(|p| p.timestamp < cutoff) {
            self.packets.pop_front();
        }
        self.packets.push_back(packet);
    }
    pub fn len(&self) -> usize {
        self.packets.len()
    }
    pub fn is_empty(&self) -> bool {
        self.packets.is_empty()
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn evicts_stale_packets() {
        let mut b = PacketBuffer::new(Duration::from_secs(5));
        b.push(Packet {
            timestamp: Duration::from_secs(1),
            value: 1,
        });
        b.push(Packet {
            timestamp: Duration::from_secs(7),
            value: 2,
        });
        assert_eq!(b.len(), 1);
        assert!(!b.is_empty());
        assert_eq!(b.packets.front().map(|packet| packet.value), Some(2));
    }
}
