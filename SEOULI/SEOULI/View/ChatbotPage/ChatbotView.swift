//
//  ChatbotView.swift
//  SEOULI
//
//  Created by 김소리 on 6/25/24.
//

/*
 Author : 김수민
 
 Date : 2024.06.28 Friday
 Description : 1차 UI 작업, R&D 시작
 
 Date : 2024.07.01 Monday
 Description : 2차 UI 및 R&D 작업
 
 Date : 2024.07.02 Tuesady
 Description : R&D 작업
 
 Date : 2024.07.03 Wednesday
 Description : 모델사용해서 추천해주기
 
 Date : 2024.07.04 Thursday
 Description : 추천장소 링크걸어 해당하는 디테일페이지 이동 완료
 
*/

import SwiftUI

// MESSAGE MODEL
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromCurrentUser: Bool
    let recommendations: [SeoulList]?
    
    init(text: String, isFromCurrentUser: Bool, recommendations: [SeoulList]? = nil) {
        self.text = text
        self.isFromCurrentUser = isFromCurrentUser
        self.recommendations = recommendations
    }
}

struct ChatbotView: View {
    @State private var isAnimating = false
    @State private var isSheetPresented = false
    @State private var isLoading = false
    @State private var message = ""
    @State private var messages: [ChatMessage] = []
    @StateObject private var networkManager = NetworkManager()
    @FocusState private var isInputActive: Bool
    @State private var isFirstTimePresented = true
    
    var body: some View {
        ZStack {
            // HWIBOT Floating Button
            Button(action: {
                withAnimation(.spring()) {
                    isSheetPresented.toggle()
                }
            }) {
                Image("bot")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 40)
                    .padding()
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .offset(x: 0, y: isAnimating ? -20 : 0)
            .position(x: UIScreen.main.bounds.width - 50, y: UIScreen.main.bounds.height - 60)
            .onAppear {
                startAnimation()
            }
            .onChange(of: isSheetPresented) {
                if !isSheetPresented {
                    startAnimation()
                }
            }
            
            // Chat Screen
            if isSheetPresented {
                ChatBubble(
                    isPresented: $isSheetPresented,
                    isLoading: $isLoading,
                    message: $message,
                    messages: $messages,
                    networkManager: networkManager
                )
                .transition(.move(edge: .bottom))
                .zIndex(1)
                .onAppear {
                    // Ensure sendInitialMessage() is called only once
                    if isFirstTimePresented {
                        sendInitialMessage()
                        isFirstTimePresented = false
                    }
                }
            }
        }
    }
    
    private func sendInitialMessage() {
        let initialMessage = "추천받고 싶은 장소에 대한 키워드를 입력해주세요!😊"
        let botMessage = ChatMessage(text: initialMessage, isFromCurrentUser: false)
        messages.append(botMessage)
    }
    
    // ANIMATION FOR HWIBOT BUTTON
    private func startAnimation() {
        isAnimating = true
        withAnimation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
            isAnimating.toggle()
        }
    }
}

struct ChatBubble: View {
    @Binding var isPresented: Bool
    @Binding var isLoading: Bool
    @Binding var message: String
    @Binding var messages: [ChatMessage]
    @ObservedObject var networkManager: NetworkManager
    @FocusState private var isInputActive: Bool

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                    isInputActive = false // Hide keyboard
                }) {
                    Image(systemName: "xmark")
                        .padding()
                        .clipShape(Circle())
                }
                .padding()
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(messages) { msg in
                        // Display different types of messages in ChatBubbleRow
                        if msg.text == "추천받고 싶은 장소에 대한 키워드를 입력해주세요!😊" {
                            Text(msg.text)
                                .foregroundColor(.black)
                                .padding(10)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(10)
                                .padding(.trailing,123)
                        } else {
                            ChatBubbleRow(
                                text: msg.text,
                                isFromCurrentUser: msg.isFromCurrentUser,
                                recommendations: msg.recommendations,
                                networkManager: networkManager
                            )
                        }
                    }
                    if isLoading {
                        LoadingBubbleView()
                    }
                }
                .padding(.vertical)
            }

            HStack {
                TextField("키워드를 입력하세요!", text: $message)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(36)
                    .overlay(RoundedRectangle(cornerRadius: 36).stroke(Color.gray.opacity(0.6), lineWidth: 1))
                    .frame(height: 50)
                    .focused($isInputActive)

                Button(action: {
                    if !message.isEmpty {
                        sendMessage()
                        message = ""
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.blue)
                        .padding(6)
                }
            }
            .padding(.bottom, 15)
            .padding()
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding(.horizontal)
        .frame(maxHeight: 500)
        .offset(y: isPresented ? 0 : UIScreen.main.bounds.height)
        .animation(.spring(), value: isPresented)
    }

    private func sendMessage() {
        let userMessage = ChatMessage(text: message, isFromCurrentUser: true)
        messages.append(userMessage)

        isLoading = true

        networkManager.fetchRecommendations(for: userMessage.text) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let recommendations):
                    let responseText = recommendations.map { "장소명: \($0.name)\n주소📍 \($0.address)" }.joined(separator: "\n\n")
                    let responseMessage = ChatMessage(
                        text: responseText,
                        isFromCurrentUser: false,
                        recommendations: recommendations
                    )
                    messages.append(responseMessage)
                case .failure(let error):
                    let errorMessage = ChatMessage(text: "Error: \(error.localizedDescription)", isFromCurrentUser: false)
                    messages.append(errorMessage)
                }
                isLoading = false
            }
        }

        message = ""
        isInputActive = false
    }
}

struct ChatBubbleRow: View {
    let text: String
    let isFromCurrentUser: Bool
    let recommendations: [SeoulList]?
    let networkManager: NetworkManager

    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
                Text(text)
                    .padding(10)
                    .background(Color.blue.opacity(0.9))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(alignment: .leading) {
                    if let recommendations = recommendations, !recommendations.isEmpty {
                        Text("제가 추천하는 장소는...")
                            .foregroundColor(.black)
                            .padding(.bottom, 5)
                        
                        ForEach(recommendations, id: \.id) { recommendation in
                            NavigationLink(destination: SeoulListDetailView(location: recommendation)) {
                                Text("장소명: ")
                                    .foregroundColor(.black)
                                Text("\(recommendation.name)")
                                    .underline()
                                    .foregroundColor(.blue)
                            }
                            Text("주소📍 \(recommendation.address)\n")
                                .foregroundColor(.black)
                        }
                    } else {
                        Text(networkManager.norecmessage)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(10)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(10)
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

struct LoadingBubbleView: View {
    @State private var dot1Scale: CGFloat = 1.0
    @State private var dot2Scale: CGFloat = 1.0
    @State private var dot3Scale: CGFloat = 1.0
    
    var body: some View {
        HStack {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.gray.opacity(0.8))
                    .frame(width: 9, height: 9)
                    .scaleEffect(dot1Scale)
                    .animation(Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: dot1Scale)
                Circle()
                    .fill(Color.gray.opacity(0.8))
                    .frame(width: 9, height: 9)
                    .scaleEffect(dot2Scale)
                    .animation(Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0.2), value: dot2Scale)
                Circle()
                    .fill(Color.gray.opacity(0.8))
                    .frame(width: 9, height: 9)
                    .scaleEffect(dot3Scale)
                    .animation(Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0.4), value: dot3Scale)
            }
            .padding(15)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(20)
            Spacer()
        }
        .onAppear {
            dot1Scale = 1.3
            dot2Scale = 1.3
            dot3Scale = 1.3
        }
        .padding(.horizontal)
    }
}

#Preview {
    ChatbotView()
}
