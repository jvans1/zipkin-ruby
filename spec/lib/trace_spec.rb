require 'spec_helper'

describe Trace do
  let(:dummy_endpoint) { Trace::Endpoint.new('127.0.0.1', 9411, 'DummyService') }

  describe Trace::Span do
    let(:span_id) { 'c3a555b04cf7e099' }
    let(:parent_id) { 'f0e71086411b1445' }
    let(:annotations) { [
      Trace::Annotation.new(Trace::Annotation::SERVER_RECV, dummy_endpoint).to_h,
      Trace::Annotation.new(Trace::Annotation::SERVER_SEND, dummy_endpoint).to_h
    ] }
    let(:span_without_parent) do
      Trace::Span.new('get', Trace::TraceId.new(span_id, nil, span_id, true, Trace::Flags::EMPTY))
    end
    let(:span_with_parent) do
      Trace::Span.new('get', Trace::TraceId.new(span_id, parent_id, span_id, true, Trace::Flags::EMPTY))
    end

    before do
      [span_with_parent, span_without_parent].each do |span|
        annotations.each { |a| span.annotations << a }
      end
    end

    describe '#to_h' do
      it 'returns a hash representation of a span' do
        expected_hash = {
          name: 'get',
          traceId: span_id,
          id: span_id,
          parentId: nil,
          annotations: annotations,
          binaryAnnotations: [],
          debug: false
        }
        expect(span_without_parent.to_h).to eq(expected_hash)
        expect(span_with_parent.to_h).to eq(expected_hash.merge(parentId: parent_id))
      end
    end
  end

  describe Trace::Annotation do
    let(:annotation) { Trace::Annotation.new(Trace::Annotation::SERVER_RECV, dummy_endpoint) }

    describe '#to_h' do
      before { Timecop.freeze(Time.utc(2016, 1, 16, 23, 45)) }

      it 'returns a hash representation of an annotation' do
        expect(annotation.to_h).to eq(
          value: 'sr',
          timestamp: 1452987900000000,
          endpoint: dummy_endpoint.to_h
        )
      end
    end
  end

  describe Trace::BinaryAnnotation do
    let(:annotation) { Trace::BinaryAnnotation.new('http.uri', '/', 'STRING', dummy_endpoint) }

    describe '#to_h' do
      it 'returns a hash representation of a binary annotation' do
        expect(annotation.to_h).to eq(
          key: 'http.uri',
          value: '/',
          endpoint: dummy_endpoint.to_h
        )
      end
    end
  end

  describe Trace::Endpoint do
    describe '.make_endpoint' do
      let(:service_name) { 'service name' }
      let(:hostname) { 'z2.example.com' }

      context 'host lookup success' do
        before do
          allow(Socket).to receive(:getaddrinfo).with('z1.example.com', nil, :INET).
            and_return([['', '', '', '8.8.4.4']])
          allow(Socket).to receive(:getaddrinfo).with('z2.example.com', nil, :INET).
            and_return([['', '', '', '8.8.8.8']])
          allow(Socket).to receive(:getaddrinfo).with('z2.example.com', nil).
            and_return([['', '', '', '8.8.8.8']])
        end

        it 'translates a given hostname to an ipv4 as an i32' do
          ep = ::Trace::Endpoint.make_endpoint(hostname, 80, service_name, :i32)
          expect(ep.ipv4).to eq(0x8080808)
          expect(ep.ip_format).to eq(:i32)
        end

        it 'translates a given hostname to an ipv4 as a string' do
          ep = ::Trace::Endpoint.make_endpoint(hostname, 80, service_name, :string)
          expect(ep.ipv4).to eq('8.8.8.8')
          expect(ep.ip_format).to eq(:string)
        end

        it 'auto detects the hostname' do
          allow(Socket).to receive(:gethostname).and_return('z1.example.com')
          ep = ::Trace::Endpoint.make_endpoint(nil, 80, service_name, :string)
          expect(ep.ipv4).to eq('8.8.4.4')
          expect(ep.ip_format).to eq(:string)
        end
      end

      context 'host lookup failure' do
        before { allow(Socket).to receive(:gethostname).and_raise }

        it 'falls back to localhost as an i32' do
          ep = ::Trace::Endpoint.make_endpoint(hostname, 80, service_name, :i32)
          expect(ep.ipv4).to eq(0x7f000001)
          expect(ep.ip_format).to eq(:i32)
        end

        it 'falls back to 127.0.0.1' do
          ep = ::Trace::Endpoint.make_endpoint(hostname, 80, service_name, :string)
          expect(ep.ipv4).to eq('127.0.0.1')
          expect(ep.ip_format).to eq(:string)
        end
      end
    end

    describe '#to_h' do
      it 'returns a hash representation of an endpoint' do
        expect(dummy_endpoint.to_h).to eq(
          ipv4: '127.0.0.1',
          port: 9411,
          serviceName: 'DummyService'
        )
      end
    end
  end
end